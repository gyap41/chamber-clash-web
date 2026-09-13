extends RefCounted
# Battle authority service. Context supplies actors, field, storage and optional event sink.
# No HUD, match score, preparation or scene-navigation dependency.
const Effects = preload("res://scripts/combat/relic_effects.gd")
const Relics = preload("res://scripts/catalog/relic_catalog.gd")
const Victory = preload("res://scripts/combat/victory_rule.gd")
var context: WeakRef
var game:
	get: return context.get_ref()
func _init(value) -> void: context = weakref(value)
func step(dt: float) -> void:
	if game.phase != "play" or game.paused or not game.result.is_empty() or not settled_outcome.is_empty(): return
	game.remaining -= dt
	_step_delayed_shots(dt)
	_step_players(dt)
	game.supplies.step(dt)
	_step_projectiles(dt)
	_step_wells(dt)
var settled_outcome: Dictionary = {}
func reset_outcome() -> void: settled_outcome = {}
func outcome() -> Dictionary:
	if settled_outcome.is_empty(): settled_outcome = Victory.evaluate(game.roster,game.players,game.remaining <= 0)
	return settled_outcome.duplicate(true)

func use_pulse(index: int) -> bool:
	if index < 0 or index >= game.players.size() or game.phase != "play" or game.paused or game.result != "": return false
	var p: Dictionary = game.players[index].state
	if p.hp <= 0 or p.pulses <= 0: return false
	p.pulses -= 1
	Effects.pulse_used(game.players[index])
	game.telemetry.record("pulse",{"player":index,"remaining":p.pulses})
	game.presentation.shake(5.0)
	game.presentation.play_sound("boom",0)
	p.last_volley = -1
	p.inv = maxf(p.inv,game.players[index].pulse_invulnerability)
	game.delayed_shots = game.delayed_shots.filter(func(shot): return not game.roster.hostile(index,shot.owner))
	for collection in [game.shots,game.wells]:
		for n in range(collection.size()-1,-1,-1):
			if game.roster.hostile(index,collection[n].state.owner):
				var node = collection.pop_at(n)
				node.get_parent().remove_child(node)
				node.queue_free()
	game.presentation.pulse(p.pos,index)
	if 9 in game.players[index].relics:
		for n in range(6):
			spawn_shot(index,0,n*TAU/6,{"kind":"pulse_relay","speed":200.0,"damage":.35,"life":1.2,"can_lens":false,"depth":1})
	game.supplies.announce("P%d：パルス！ 敵弾・敵重力場・敵の追射予約を消去" % (index+1))
	return true
# 残響ホルスター: turn a Player-requested delayed follow-up into an actual delayed_shots
# entry. Reuses the existing echo-companion queue/processing wholesale (see _physics_process
# below), which is also how it gets pulse-clearing "for free" - use_pulse() already drops any
# delayed_shots entry the pulsing player does not own.

func _on_delayed_shot_requested(data: Dictionary, owner_index: int) -> void:
	game.origin_counter += 1
	var entry := data.duplicate()
	entry.owner = owner_index
	entry.root = game.origin_counter
	if not entry.has("volley"): entry.volley = -1
	game.delayed_shots.append(entry)
# Dispatch for projectile.gd's derived_shot_requested (currently only 反響の種, id 12): keeps
# the relic's numeric tuning in the catalog / here, not duplicated inside combat/projectile.gd.

func _on_projectile_derived_shot(owner_index: int, pos: Vector2, relic_id: int) -> void:
	var relic := Relics.definition(relic_id)
	match relic_id:
		12:
			spawn_shot(owner_index,0,0.0,{"kind":"echo_seed","pos":pos,"damage":float(relic.get("seed_damage",.4)),"speed":0.0,"life":float(relic.get("seed_life",1.2)),"radius":float(relic.get("seed_radius",5.0)),"color":relic.color,"can_lens":false,"depth":1})

func fire(index: int) -> void:
	if game.phase != "play" or game.paused or game.result != "" or not game.players[index].can_fire(): return
	var player = game.players[index]
	var g: Dictionary = player.definition()
	var w: Dictionary = player.weapon()
	var scatter: bool = g.get("switcher", false) and w.mode == 1
	var count: int = 3 if scatter else int(g.get("count", 1))
	var burst_count := int(g.get("burst_count",1))
	var trigger := Effects.shooting(player,g,w,scatter,count,burst_count)
	var first_shot: bool = trigger.first
	var shot_damage: float = trigger.damage
	var echo_damage: float = trigger.echo_damage
	var damage_scale: float = trigger.damage_scale
	var speed_scale: float = trigger.speed_scale
	game.volley_counter += 1
	game.origin_counter += 1
	game.telemetry.record("fire",{"player":index,"weapon":w.id,"root":game.origin_counter,"volley":game.volley_counter,"pellets":count})
	for i in range(count):
		var angle: float = player.state.angle + (i-(count-1)/2.0) * (.16 if scatter else float(g.get("spread", .11)))
		if g.has("alternate_spread"): angle += float(g.alternate_spread)*(1 if int(player.state.alternate_shots)%2 == 0 else -1)
		if g.get("cross",false): angle = player.state.angle+(-.10 if i < 2 else .10)
		if g.get("radial", false): angle = player.state.angle + i*TAU/count
		var opts := {"root":game.origin_counter,"phase":1 if i % 2 else -1,"damage":shot_damage,"volley":game.volley_counter,"parcel":g.get("parcel",false) and w.clip == 1,"depth":0}
		opts.damage_scale = damage_scale
		opts.speed_scale = speed_scale
		if g.get("cross",false):
			opts.cross_turn = .20 if i < 2 else -.20
			opts.pos = player.state.pos+Vector2.from_angle(angle)*(21.0 if i%2 == 0 else 29.0)
		if g.get("prism", false): opts.color = ["#ff9bbd","#ffe99b","#98efd0","#a4d9ff","#dfafff"][i % 5]
		var palette: Array = preload("res://scripts/catalog/weapon_visual_catalog.gd").profile(w.id).get("palette",[])
		if not palette.is_empty(): opts.visual_color = palette[i%palette.size()]
		spawn_shot(index, w.id, angle, opts)
		for followup in range(1,burst_count):
			var delayed := opts.duplicate(true)
			delayed.merge({"owner":index,"gun":w.id,"angle":angle,"delay":float(g.get("burst_delay",.08))*followup,"kind":"burst"},true)
			game.delayed_shots.append(delayed)
	if g.get("echo", false):
		game.delayed_shots.append({"root":game.origin_counter,"owner":index,"gun":w.id,"angle":player.state.angle,"delay":.24,"volley":game.volley_counter,"damage":echo_damage,"kind":"echo","depth":1})
	# 空薬莢の祝福: only the next *first* shot (full magazine) after an empty-clip reload
	# consumes the charge, matching "次の初射"; 余熱コンデンサ has no such qualifier and is
	# spent by the very next fire() call regardless of magazine state. Both are one-shot bonus
	# pellets, depth 1, can't re-trigger any further P3 generation.
	if 13 in player.relics and first_shot and player.state.get("empty_casing_charge", false):
		player.state.empty_casing_charge = false
		var relic13 := Relics.definition(13)
		spawn_shot(index,0,player.state.angle,{"kind":"empty_casing","damage":float(relic13.get("casing_damage",.5)),"speed":g.speed*float(relic13.get("casing_speed_ratio",.75)),"life":1.6,"radius":4.0,"color":relic13.color,"can_lens":false,"depth":1})
	if 15 in player.relics and player.state.get("residual_heat_charge", false):
		player.state.residual_heat_charge = false
		var relic15 := Relics.definition(15)
		spawn_shot(index,0,player.state.angle,{"kind":"residual_heat","damage":float(relic15.get("heat_damage",.4)),"speed":g.speed*float(relic15.get("heat_speed_ratio",.85)),"life":1.6,"radius":4.0,"color":relic15.color,"can_lens":false,"depth":1})
	player.consume_shot()
	preload("res://scripts/combat/weapon_behaviors.gd").dispatch(w.id,&"fire",{"actor":player,"session":self,"weapon":w})
	if g.get("comet",false) or g.get("prism",false): game.presentation.shake(3.0)
	game.presentation.weapon_event({"kind":"fire","weapon":w.id,"owner":index,"pos":player.presentation_muzzle(w.id,player.state.angle),"angle":player.state.angle})
	game.presentation.play_sound("shot",w.id)

func spawn_shot(index: int, id: int, angle: float, opts: Dictionary = {}) -> void:
	opts = opts.duplicate()
	if not opts.has("root"):
		game.origin_counter += 1
		opts.root = game.origin_counter
	var bullet = game.projectile_scene.instantiate()
	game.arena.get_node("Projectiles").add_child(bullet)
	bullet.launch(game.players[index],index,id,angle,opts)
	bullet.set_meta("origin",opts.root)
	bullet.burst_requested.connect(game.presentation.burst)
	bullet.visual_event_requested.connect(game.presentation.weapon_event)
	bullet.derived_shot_requested.connect(_on_projectile_derived_shot)
	game.shots.append(bullet)
	game.telemetry.record("projectile",{"player":index,"weapon":id,"root":opts.get("root",opts.get("volley",-1)),"kind":opts.get("kind","shot"),"volley":opts.get("volley",-1)})

func spawn_well(pos: Vector2, owner_index: int):
	var well = game.gravity_well_scene.instantiate()
	game.arena.get_node("Wells").add_child(well)
	well.launch(pos,owner_index)
	game.wells.append(well)
	game.presentation.play_sound("gravity",0)
	return well

func _step_delayed_shots(dt: float) -> void:
	for n in range(game.delayed_shots.size()-1,-1,-1):
		var delayed: Dictionary = game.delayed_shots[n]
		delayed.delay -= dt
		if delayed.delay <= 0:
			spawn_shot(delayed.owner,delayed.gun,delayed.angle,delayed)
			var actor = game.players[delayed.owner]
			game.presentation.weapon_event({"kind":"fire","weapon":delayed.gun,"owner":delayed.owner,"pos":actor.presentation_muzzle(delayed.gun,delayed.angle),"angle":delayed.angle})
			game.delayed_shots.remove_at(n)


func _step_projectiles(dt: float) -> void:
	for b in game.shots.duplicate(): b.step(dt,game.arena,game.roster.enemies(b.state.owner,game.players))
	for n in range(game.shots.size()-1,-1,-1):
		var b = game.shots[n]
		if b.state.dead or b.state.life <= 0:
			if not b.state.dead:
				b.notify_visual("split" if not b.fragments().is_empty() else "expire",b.state.pos)
				if b.state.parcel: game.presentation.ring(b.state.pos,Color(b.state.color),55.0)
				if b.state.gravity: game.presentation.ring(b.state.pos,Color(b.state.color),100.0)
				if b.state.split or b.state.clover or b.state.comet:
					game.presentation.burst(b.state.pos,Color(b.state.color),32 if b.state.comet else 20)
					game.presentation.ring(b.state.pos,Color(b.state.color),95.0 if b.state.comet else 45.0)
				if b.state.comet:
					for enemy in game.roster.enemies(b.state.owner,game.players):
						if b.state.pos.distance_to(enemy.state.pos) < b.comet_blast_radius and not game.arena.line_blocked(b.state.pos,enemy.state.pos): enemy.hurt(b.comet_blast_damage)
					game.presentation.shake(5.0)
				if b.state.gravity: spawn_well(b.state.pos,b.state.owner)
			var fragments: Dictionary = b.fragments()
			if not fragments.is_empty():
				for shard in range(fragments.count):
					spawn_shot(b.state.owner,0,shard*TAU/fragments.count,{"kind":"fragment","visual_weapon":b.visual_id,"visual_variant":preload("res://scripts/catalog/weapon_visual_catalog.gd").profile(b.visual_id).get("fragment","derived"),"root":b.get_meta("origin",-1),"pos":b.state.pos,"speed":fragments.speed,"damage":fragments.damage,"life":fragments.life,"color":fragments.color,"radius":4.0,"can_lens":false,"depth":1})
			game.shots.remove_at(n)
			b.get_parent().remove_child(b)
			b.queue_free()


func _step_wells(dt: float) -> void:
	for well in game.wells: well.step(dt,game.arena,game.players,game.shots,game.roster)
	for n in range(game.wells.size()-1,-1,-1):
		if game.wells[n].state.life <= 0:
			var well = game.wells.pop_at(n)
			well.get_parent().remove_child(well)
			well.queue_free()
	# Absorption removes enemy shots without impact effects or new wells.
	for n in range(game.shots.size()-1,-1,-1):
		if game.shots[n].state.dead:
			var shot = game.shots.pop_at(n)
			shot.get_parent().remove_child(shot)
			shot.queue_free()


func apply_command(index: int, command: Dictionary) -> void:
	if index < 0 or index >= game.players.size() or game.phase != "play" or game.paused or not game.result.is_empty(): return
	var player = game.players[index]
	if player.state.hp <= 0: return
	if command.has("angle"): player.state.angle = float(command.angle)
	if int(command.get("switch",-1)) >= 0: player.request_switch(int(command.switch))
	if command.get("dodge",false):
		var direction := Vector2(command.get("dx",0.0),command.get("dy",0.0)).normalized()
		if not direction.is_zero_approx(): player.state.dir = direction
		if player.try_dodge():
			for n in range(6): spawn_shot(index,0,n*TAU/6,{"kind":"dodge_nova","speed":250.0,"damage":.35,"life":1.2,"radius":4.0,"color":"#ecc5ff","can_lens":false,"depth":1})
	if command.get("reload",false): player.start_reload()
	if command.get("melee",false): player.try_melee(index,game.shots,game.roster.enemies(index,game.players),game.arena)
	if command.get("pulse",false): use_pulse(index)
	if command.get("interact",false): game.supplies.interact(index)
	if command.get("fire_pressed",false): player.request_fire()
# Authority caller supplies a participant ID, never an arbitrary array address from payload.

func _step_players(dt: float) -> void:
	for i in range(game.players.size()):
		var player = game.players[i]
		if player.state.hp <= 0: continue
		var enemy = game.roster.nearest(i,game.players,player.state.pos)
		var command: Dictionary = game.command_source.call(i,dt)
		apply_command(i,command)
		if player.step(dt,i,enemy,game.arena,false,command): fire(i)
		if player.state.roll > 0: game.presentation.dodge_trail(player.state.pos,player.visual_color())
		player.try_phase_load(game.shots,i)
		game.arena.apply_hazards(player,game.arena_inset())
