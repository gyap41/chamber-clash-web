extends Node2D
const Weapons = preload("res://scripts/catalog/weapon_catalog.gd")
const Catalog = preload("res://scripts/catalog/game_catalog.gd")
const Relics = preload("res://scripts/catalog/relic_catalog.gd")
const CpuAI = preload("res://scripts/ai/cpu_ai.gd")
const Characters = preload("res://scripts/catalog/character_catalog.gd")
@export var pulse_effect_scene: PackedScene = preload("res://scenes/combat/pulse_effect.tscn")
@export var round_duration: float = 90.0
@export var projectile_scene: PackedScene = preload("res://scenes/combat/projectile.tscn")
@export var gravity_well_scene: PackedScene = preload("res://scenes/combat/gravity_well.tscn")
@onready var arena = $Arena
@onready var players: Array = [$Arena/Players/P1,$Arena/Players/P2]
@onready var hud = $HUD
var fighters: Array = [] # State views retained for the original regression API.
var shots: Array = []
var wells: Array = []
var pulse_effects: Array = []
var remaining: float
var result := ""
var paused := false
var mouse_fire_held := false
var catalog: Dictionary
const MatchState = preload("res://scripts/game/match_state.gd")
const RunLog = preload("res://scripts/game/run_log.gd")
var match_state
var telemetry
var supply_generator
var phase := "prepare"
var scores := [0, 0]
var delayed_shots: Array = []
var volley_counter := 0
var origin_counter := 0
@onready var preparation = $Preparation
@onready var supplies = $Arena/Supplies
@onready var combat_visuals = $Arena/CombatVisuals
@onready var sound = $Sound
func _ready() -> void:
	catalog = Catalog.data
	supplies.game = self
	preparation.game = self
	for i in range(players.size()):
		var player = players[i]
		player.burst_requested.connect(combat_visuals.burst)
		player.ring_requested.connect(combat_visuals.ring)
		player.shake_requested.connect(combat_visuals.shake)
		player.sound_requested.connect(sound.play_sound)
		# 残響ホルスター: Player has no back-reference to main.gd, so it asks for a delayed
		# shot via signal instead; bind the owning index since the signal itself only carries
		# the spawn data.
		player.delayed_shot_requested.connect(_on_delayed_shot_requested.bind(i))
	var seed_value := -1
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--seed="): seed_value = int(argument.trim_prefix("--seed="))
	new_match(seed_value)
func new_match(seed_value: int = -1) -> void:
	match_state = MatchState.new(seed_value if seed_value >= 0 else Time.get_ticks_usec())
	# P8z：マッチを作り直しても、選んだキャラクターの初期武器から始められるようにする。初回は
	# キャラ未選択（char_id < 0）なのでMatchState側の既定の初期武器のままで、キャラ確定時に
	# assign_character()が差し替える。
	for i in range(players.size()):
		players[i].match_inventory = match_state
		players[i].match_player_index = i
		if players[i].char_id >= 0: match_state.grant_start_weapon(i,Characters.start_gun(players[i].char_id))
	supply_generator = MatchState.Generator.new(match_state.seed_value ^ 0x51A7)
	telemetry = RunLog.new(match_state.seed_value)
	scores = match_state.scores
	result = ""
	volley_counter = 0
	origin_counter = 0
	reset_round(false)
func reset_round(check_new: bool = true) -> void:
	if check_new and (match_state == null or result == "" or scores.max() >= MatchState.WIN_TARGET):
		new_match()
		return
	var replay: bool = result == "DRAW"
	combat_visuals.clear()
	arena.get_node("CombatCamera").offset = Vector2.ZERO
	mouse_fire_held = false
	# Audio preferences belong to the session, not the build.
	supplies.reset()
	for effect in pulse_effects:
		effect.get_parent().remove_child(effect)
		effect.queue_free()
	pulse_effects.clear()
	for well in wells:
		well.get_parent().remove_child(well)
		well.queue_free()
	wells.clear()
	for b in shots:
		b.get_parent().remove_child(b)
		b.queue_free()
	shots.clear()
	delayed_shots.clear()
	fighters.clear()
	for i in range(2):
		players[i].reset(arena.get_node("Spawns/P%d" % [i+1]).position)
		players[i].telemetry = telemetry
		players[i].apply_build(match_state.builds[i],match_state.capacity(i),false,match_state.usable_cells(i))
		fighters.append(players[i].state)
	remaining = round_duration
	arena.get_node("DangerZone").refresh(0.0)
	result = ""
	paused = false
	phase = "prepare"
	preparation.begin()
	if replay: launch_round()
	hud.refresh(players,remaining,paused,result,scores,phase)
# Release is observed before GUI handling; presses start fire only outside UI.
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.keycode == KEY_L and not event.pressed:
		players[1].keyboard_fire_held = false
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		mouse_fire_held = false
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		mouse_fire_held = phase == "play" and not paused and result == ""
		if mouse_fire_held and not players[0].is_cpu: players[0].request_fire()
	# P1's melee is a right-click (mouse-driven control scheme, 2026-09-08) rather than a
	# keyboard key; it does not go through handle_key()/_unhandled_key_input at all.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		if phase == "play" and not paused and result == "" and not players[0].is_cpu:
			players[0].try_melee(0,shots,players[1],arena)
	# マウスホイールでのP1武器切替（2026-09-10追加）：Eキー・1〜4キーの既存経路には手を
	# 入れず、追加の入力経路として実装。ガード条件はEキーの巡回切替と同一
	# （phase=="play" かつ非ポーズ・非決着・非CPU）。P2はこの入力を一切参照しない。
	if event is InputEventMouseButton and event.pressed and not players[0].is_cpu:
		if phase == "play" and not paused and result == "":
			var p0 = players[0]
			# P8z ステップA：丸腰（inventoryが空）だと剰余がゼロ除算になるため、切替自体を無視する。
			var inv_size: int = p0.inventory.size()
			if inv_size > 0:
				if event.button_index == MOUSE_BUTTON_WHEEL_UP:
					p0.request_switch((int(p0.state.gun)+1) % inv_size)
				elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
					p0.request_switch((int(p0.state.gun)-1+inv_size) % inv_size)
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT: clear_action_inputs()
func clear_action_inputs() -> void:
	mouse_fire_held = false
	for player in players: player.clear_action_inputs()
func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	if event.keycode == KEY_ENTER and result != "":
		reset_round()
		return
	if phase != "play": return
	if event.keycode == KEY_ESCAPE:
		paused = not paused
		clear_action_inputs()
	if paused or result != "": return
	if event.keycode == KEY_L and not players[1].is_cpu:
		players[1].keyboard_fire_held = true
		players[1].request_fire()
	for i in range(2):
		# CPU-controlled players ignore all discrete key input (dodge/melee/reload/switch/
		# pulse/interact) exactly like legacy gates P2's key bindings behind mode==='local'.
		if players[i].is_cpu: continue
		if players[i].handle_key(event.keycode,i,shots,players[1-i],arena):
			for n in range(6):
				spawn_shot(i,0,n*TAU/6,{"kind":"dodge_nova","speed":250.0,"damage":.35,"life":1.2,"radius":4.0,"color":"#ecc5ff","can_lens":false,"depth":1})
		if event.keycode == [KEY_G,KEY_H][i]: supplies.interact(i)
		if event.keycode == [KEY_Q,KEY_O][i]: use_pulse(i)
func use_pulse(index: int) -> bool:
	if index < 0 or index >= players.size() or phase != "play" or paused or result != "": return false
	var p: Dictionary = players[index].state
	if p.hp <= 0 or p.pulses <= 0: return false
	p.pulses -= 1
	if 29 in players[index].relics: p.boots_time = players[index].relic_value(29,"boots_duration")
	telemetry.record("pulse",{"player":index,"remaining":p.pulses})
	combat_visuals.shake(5.0)
	sound.play_sound("boom",0)
	p.last_volley = -1
	p.inv = maxf(p.inv,players[index].pulse_invulnerability)
	delayed_shots = delayed_shots.filter(func(shot): return shot.owner == index)
	for collection in [shots,wells]:
		for n in range(collection.size()-1,-1,-1):
			if collection[n].state.owner != index:
				var node = collection.pop_at(n)
				node.get_parent().remove_child(node)
				node.queue_free()
	var effect = pulse_effect_scene.instantiate()
	arena.get_node("Effects").add_child(effect)
	effect.position = p.pos
	effect.modulate = Color("f39545") if index == 0 else Color("64b5ee")
	pulse_effects.append(effect)
	if 9 in players[index].relics:
		for n in range(6):
			spawn_shot(index,0,n*TAU/6,{"kind":"pulse_relay","speed":200.0,"damage":.35,"life":1.2,"can_lens":false,"depth":1})
	supplies.announce("P%d：パルス！ 敵弾・敵重力場・敵の追射予約を消去" % (index+1))
	hud.refresh(players,remaining,paused,result,scores,phase)
	return true
# 残響ホルスター: turn a Player-requested delayed follow-up into an actual delayed_shots
# entry. Reuses the existing echo-companion queue/processing wholesale (see _physics_process
# below), which is also how it gets pulse-clearing "for free" - use_pulse() already drops any
# delayed_shots entry the pulsing player does not own.
func _on_delayed_shot_requested(data: Dictionary, owner_index: int) -> void:
	origin_counter += 1
	var entry := data.duplicate()
	entry.owner = owner_index
	entry.root = origin_counter
	if not entry.has("volley"): entry.volley = -1
	delayed_shots.append(entry)
# Dispatch for projectile.gd's derived_shot_requested (currently only 反響の種, id 12): keeps
# the relic's numeric tuning in the catalog / here, not duplicated inside combat/projectile.gd.
func _on_projectile_derived_shot(owner_index: int, pos: Vector2, relic_id: int) -> void:
	var relic := Relics.definition(relic_id)
	match relic_id:
		12:
			spawn_shot(owner_index,0,0.0,{"kind":"echo_seed","pos":pos,"damage":float(relic.get("seed_damage",.4)),"speed":0.0,"life":float(relic.get("seed_life",1.2)),"radius":float(relic.get("seed_radius",5.0)),"color":relic.color,"can_lens":false,"depth":1})
func fire(index: int) -> void:
	if phase != "play" or paused or result != "" or not players[index].can_fire(): return
	var player = players[index]
	var g: Dictionary = player.definition()
	var w: Dictionary = player.weapon()
	var scatter: bool = g.get("switcher", false) and w.mode == 1
	var count: int = 3 if scatter else int(g.get("count", 1))
	var burst_count := int(g.get("burst_count",1))
	var first_shot: bool = w.clip == int(g.mag)
	var shot_damage: float = (.5 if scatter else g.damage) * (1.2 if first_shot and 7 in player.relics else 1.0)
	# 帰還バッテリー: a charge armed by the *previous* weapon switch boosts this volley once,
	# then clears itself; it cannot re-arm until another boomerang recovery + switch happens.
	if 14 in player.relics and player.state.get("return_battery_armed", false):
		# One charge belongs to the shot, shared across pellets rather than multiplied by count.
		shot_damage += float(Relics.definition(14).get("battery_bonus",.45))/(count*burst_count)
		player.state.return_battery_armed = false
	var echo_damage := shot_damage
	if w.clip == 1 and 22 in player.relics:
		shot_damage += player.relic_value(22,"last_bonus")/(count*burst_count)
	var damage_scale: float = (1.0+Relics.additive_bonus(player.relics,"shot_bonus"))*(1.15 if 6 in player.relics else 1.0)
	var speed_scale: float = (1.0+Relics.additive_bonus(player.relics,"speed_bonus"))*(.8 if 6 in player.relics else 1.0)
	if 30 in player.relics and player.state.sight_time > 0:
		speed_scale *= 1.0+player.relic_value(30,"sight_bonus")
		player.state.sight_time = 0.0
	volley_counter += 1
	origin_counter += 1
	telemetry.record("fire",{"player":index,"weapon":w.id,"root":origin_counter,"volley":volley_counter,"pellets":count})
	for i in range(count):
		var angle: float = player.state.angle + (i-(count-1)/2.0) * (.16 if scatter else float(g.get("spread", .11)))
		if g.has("alternate_spread"): angle += float(g.alternate_spread)*(1 if int(player.state.alternate_shots)%2 == 0 else -1)
		if g.get("cross",false): angle = player.state.angle+(-.10 if i < 2 else .10)
		if g.get("radial", false): angle = player.state.angle + i*TAU/count
		var opts := {"root":origin_counter,"phase":1 if i % 2 else -1,"damage":shot_damage,"volley":volley_counter,"parcel":g.get("parcel",false) and w.clip == 1,"depth":0}
		opts.damage_scale = damage_scale
		opts.speed_scale = speed_scale
		if g.get("cross",false):
			opts.cross_turn = .20 if i < 2 else -.20
			opts.pos = player.state.pos+Vector2.from_angle(angle)*(21.0 if i%2 == 0 else 29.0)
		if g.get("prism", false): opts.color = ["#ff9bbd","#ffe99b","#98efd0","#a4d9ff","#dfafff"][i % 5]
		spawn_shot(index, w.id, angle, opts)
		for followup in range(1,burst_count):
			var delayed := opts.duplicate(true)
			delayed.merge({"owner":index,"gun":w.id,"angle":angle,"delay":float(g.get("burst_delay",.08))*followup,"kind":"burst"},true)
			delayed_shots.append(delayed)
	if g.get("echo", false):
		delayed_shots.append({"root":origin_counter,"owner":index,"gun":w.id,"angle":player.state.angle,"delay":.24,"volley":volley_counter,"damage":echo_damage,"kind":"echo","depth":1})
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
	if g.get("comet",false) or g.get("prism",false): combat_visuals.shake(3.0)
	combat_visuals.burst(player.state.pos+Vector2.from_angle(player.state.angle)*26,Color(g.color),12 if g.get("prism",false) else 4)
	sound.play_sound("shot",w.id)
func spawn_shot(index: int, id: int, angle: float, opts: Dictionary = {}) -> void:
	opts = opts.duplicate()
	if not opts.has("root"):
		origin_counter += 1
		opts.root = origin_counter
	var bullet = projectile_scene.instantiate()
	arena.get_node("Projectiles").add_child(bullet)
	bullet.launch(players[index],index,id,angle,opts)
	bullet.set_meta("origin",opts.root)
	bullet.burst_requested.connect(combat_visuals.burst)
	bullet.weapon_effect_requested.connect(combat_visuals.weapon_effect)
	bullet.derived_shot_requested.connect(_on_projectile_derived_shot)
	shots.append(bullet)
	telemetry.record("projectile",{"player":index,"weapon":id,"root":opts.get("root",opts.get("volley",-1)),"kind":opts.get("kind","shot"),"volley":opts.get("volley",-1)})
func spawn_well(pos: Vector2, owner_index: int):
	var well = gravity_well_scene.instantiate()
	arena.get_node("Wells").add_child(well)
	well.launch(pos,owner_index)
	wells.append(well)
	sound.play_sound("gravity",0)
	return well
func launch_round() -> void:
	if phase != "prepare" or not match_state.ready.all(func(value): return value): return
	mouse_fire_held = false
	phase = "play"
	for i in range(2):
		players[i].reset(arena.get_node("Spawns/P%d" % [i+1]).position)
		players[i].apply_build(match_state.builds[i],match_state.capacity(i),true,match_state.usable_cells(i))
		fighters[i] = players[i].state
	match_state.start_round()
	telemetry.record("round_start",{"stage":match_state.stage,"builds":match_state.previous})
	supplies.launch()
	preparation.refresh()
# P8z：キャラクターの適用と初期武器の付与をまとめた入口。main.tscnの_ready()が先にnew_match()
# を走らせてしまうため、キャラが決まった時点でここを呼んで、初期武器を所持庫へ入れ直したビルドを
# プレイヤーへ反映する（scripts/ui/character_select.gdのstart_match()から呼ばれる）。
func assign_character(index: int, char_id: int) -> void:
	players[index].set_character(char_id)
	match_state.grant_start_weapon(index,Characters.start_gun(char_id))
	players[index].apply_build(match_state.builds[index],match_state.capacity(index),false,match_state.usable_cells(index))
func equip_slot(index: int, slot: int) -> void:
	if phase == "play" and not paused and result == "" and not players[index].is_cpu: players[index].request_switch(slot)
# Danger zone: the safe area starts shrinking 60s into the round (7px/sec, capped at 195px
# inset from each wall) and never shrinks back. Matches the legacy web version's arenaInset().
func arena_inset() -> float:
	var elapsed: float = round_duration - remaining
	return 0.0 if elapsed <= 60.0 else minf(195.0,(elapsed-60.0)*7.0)
func move_fighter(p: Dictionary, delta: Vector2) -> void:
	arena.move_fighter(p,delta)
func _physics_process(dt: float) -> void:
	if phase == "play" and not paused and result == "":
		# Order matters: delayed shots precede player actions, projectile impacts precede
		# well absorption, and settlement observes all damage from this frame.
		remaining -= dt
		combat_visuals.step(dt)
		_step_pulse_effects(dt)
		_step_delayed_shots(dt)
		_step_players(dt)
		supplies.step(dt)
		_step_projectiles(dt)
		_step_wells(dt)
		_settle_round()
	arena.get_node("DangerZone").refresh(arena_inset() if phase in ["play","result"] else 0.0)
	arena.get_node("CombatCamera").offset = -combat_visuals.shake_offset
	hud.refresh(players,remaining,paused,result,scores,phase)

func _step_pulse_effects(dt: float) -> void:
	for n in range(pulse_effects.size()-1,-1,-1):
		if pulse_effects[n].step(dt):
			var effect = pulse_effects.pop_at(n)
			effect.get_parent().remove_child(effect)
			effect.queue_free()

func _step_delayed_shots(dt: float) -> void:
	for n in range(delayed_shots.size()-1,-1,-1):
		var delayed: Dictionary = delayed_shots[n]
		delayed.delay -= dt
		if delayed.delay <= 0:
			spawn_shot(delayed.owner,delayed.gun,delayed.angle,delayed)
			combat_visuals.weapon_effect(3,players[delayed.owner].state.pos+Vector2.from_angle(delayed.angle)*34,delayed.angle)
			delayed_shots.remove_at(n)

func _step_players(dt: float) -> void:
	for i in range(2):
		var ai: Dictionary = CpuAI.decide(self,players[i],players[1-i],dt) if players[i].is_cpu else {}
		if players[i].step(dt,i,players[1-i],arena,mouse_fire_held,ai): fire(i)
		if players[i].state.roll > 0: combat_visuals.dodge_trail(players[i].state.pos,players[i].visual_color())
		players[i].try_phase_load(shots,i)
		var inset: float = arena_inset()
		if inset > 0.0:
			var pos: Vector2 = players[i].state.pos
			if pos.x < inset+25 or pos.x > 1120-inset-25 or pos.y < inset*.58+25 or pos.y > 600-inset*.58-25:
				players[i].hurt(.16,-1,true)

func _step_projectiles(dt: float) -> void:
	for b in shots.duplicate(): b.step(dt,arena,players[1-b.state.owner])
	for n in range(shots.size()-1,-1,-1):
		var b = shots[n]
		if b.state.dead or b.state.life <= 0:
			if not b.state.dead:
				if b.state.parcel: combat_visuals.weapon_effect(1,b.state.pos)
				if b.state.parcel: combat_visuals.ring(b.state.pos,Color(b.state.color),55.0)
				if b.state.gravity: combat_visuals.ring(b.state.pos,Color(b.state.color),100.0)
				if b.state.split or b.state.clover or b.state.comet:
					combat_visuals.burst(b.state.pos,Color(b.state.color),32 if b.state.comet else 20)
					combat_visuals.ring(b.state.pos,Color(b.state.color),95.0 if b.state.comet else 45.0)
				if b.state.comet:
					var enemy = players[1-b.state.owner]
					if b.state.pos.distance_to(enemy.state.pos) < b.comet_blast_radius and not arena.line_blocked(b.state.pos,enemy.state.pos): enemy.hurt(b.comet_blast_damage)
					combat_visuals.shake(5.0)
				if b.state.gravity: spawn_well(b.state.pos,b.state.owner)
			var fragments: Dictionary = b.fragments()
			if not fragments.is_empty():
				for shard in range(fragments.count):
					spawn_shot(b.state.owner,0,shard*TAU/fragments.count,{"kind":"fragment","root":b.get_meta("origin",-1),"pos":b.state.pos,"speed":fragments.speed,"damage":fragments.damage,"life":fragments.life,"color":fragments.color,"radius":4.0,"can_lens":false,"depth":1})
			shots.remove_at(n)
			b.get_parent().remove_child(b)
			b.queue_free()

func _step_wells(dt: float) -> void:
	for well in wells: well.step(dt,arena,players,shots)
	for n in range(wells.size()-1,-1,-1):
		if wells[n].state.life <= 0:
			var well = wells.pop_at(n)
			well.get_parent().remove_child(well)
			well.queue_free()
	# Absorption removes enemy shots without impact effects or new wells.
	for n in range(shots.size()-1,-1,-1):
		if shots[n].state.dead:
			var shot = shots.pop_at(n)
			shot.get_parent().remove_child(shot)
			shot.queue_free()

func _settle_round() -> void:
	if remaining <= 0 or fighters[0].hp <= 0 or fighters[1].hp <= 0:
		var ratio1: float = fighters[0].hp/fighters[0].max_hp
		var ratio2: float = fighters[1].hp/fighters[1].max_hp
		result = "DRAW" if absf(ratio1-ratio2) < .001 else ("P1 WINS" if ratio1 > ratio2 else "P2 WINS")
		phase = "result"
		delayed_shots.clear()
		clear_action_inputs()
		match_state.finish(-1 if result == "DRAW" else (0 if result == "P1 WINS" else 1),players)
		telemetry.record("round_end",{"result":result,"seconds":round_duration-remaining,"scores":scores})

func _process(dt: float) -> void:
	if phase == "play" and not paused and result == "" and telemetry != null:
		telemetry.frame(dt,shots.size())
