extends Node2D
signal burst_requested(pos: Vector2, color: Color, count: int)
signal weapon_effect_requested(row: int, pos: Vector2, angle: float)
# P3 synergy relic (反響の種): fired at most once per bullet, only from a depth-0 (directly
# fired, non-derived) bullet's first wall bounce. main.gd owns the numeric relic definition and
# turns this into an actual spawn_shot() call, keeping this script relic-number-agnostic.
signal derived_shot_requested(owner_index: int, pos: Vector2, relic_id: int)
var switcher := false
var gun_id := 0
var speed: float = 420.0
@export var lifetime: float = 2.8
@export var comet_blast_radius := 82.0
@export var comet_blast_damage := 1.5
var radius: float = 4.0
var damage: float = 1.0
var bank_bonus: float = .25
const Weapons = preload("res://scripts/catalog/weapon_catalog.gd")
var source_player
var state: Dictionary
var log_origin: Dictionary = {}
func launch(player, index: int, id: int = 0, angle: float = 0.0, opts: Dictionary = {}) -> void:
	gun_id = id
	log_origin = {"root":opts.get("root",-1),"kind":opts.get("kind","shot"),"weapon":id,"player":index}
	source_player = player
	var p = player.state
	# P5: use the player's own weapon-mod-aware definition (falls back to the plain catalog
	# entry when this id has no active branch) so a modded weapon's damage/speed/bounce/etc.
	# apply to every bullet spawned from it, including derived shots that pass id=this gun.
	var g: Dictionary = player.resolved_definition(id)
	bank_bonus = float(g.get("bank_bonus",.25))
	switcher = g.get("switcher",false)
	speed = opts.get("speed", g.speed)
	damage = opts.get("damage", g.damage)
	var direct := int(opts.get("depth",0)) == 0
	var damage_scale: float = (1.0+player.Relics.additive_bonus(player.relics,"shot_bonus") if direct else 1.0)*(1.15 if 6 in player.relics else 1.0)
	var speed_scale: float = (1.0+player.Relics.additive_bonus(player.relics,"speed_bonus") if direct else 1.0)*(.8 if 6 in player.relics else 1.0)
	damage *= float(opts.get("damage_scale",damage_scale))
	speed *= float(opts.get("speed_scale",speed_scale))
	if g.get("comet",false): lifetime = 1.45
	elif g.get("gravity",false): lifetime = 1.35
	lifetime = opts.get("life", float(g.get("seed_life",4.8)) if g.get("seed",false) else (.8 if g.get("clover",false) else (.68 if g.get("split",false) else (1.8 if g.get("boomerang",false) else lifetime))))
	radius = opts.get("radius", 9.0 if opts.get("parcel", false) else (8.0 if g.get("boomerang",false) else (4.0 if g.get("rail",false) else 5.0)))
	if g.get("comet",false): radius = opts.get("radius",11.0)
	elif g.get("gravity",false): radius = opts.get("radius",10.0)
	elif g.get("seed",false): radius = opts.get("radius",9.0)
	var special: bool = g.get("split",false) or g.get("comet",false) or g.get("gravity",false) or g.get("boomerang",false) or g.get("seed",false) or g.get("bubble",false) or g.get("clover",false)
	var can_lens: bool = opts.get("can_lens", true)
	var bounce: int = int(g.get("bounce",0)) + (1 if (not special and can_lens and 2 in player.relics) else 0)
	# depth: 0 for a bullet fired directly by fire()/handle_key()/etc.; >=1 for anything spawned
	# as a consequence of another bullet or effect (fragments, echo companion, dodge nova, pulse
	# relay, and every P3 synergy bonus below). applied_effects is a small audit trail of which
	# one-shot bonuses this specific bullet has already consumed, so a given bullet can't trigger
	# the same generation effect twice (e.g. a bullet that somehow bounces more than once still
	# only ever spawns one Echo Seed pool). Derived (depth>0) bullets are excluded from every P3
	# synergy trigger below on purpose — "派生効果は原則さらに別の生成効果を発動しない".
	state = {"comet":g.get("comet",false),"gravity":g.get("gravity",false),"split":g.get("split",false),"clover":g.get("clover",false),"boomerang":g.get("boomerang",false),"helix":g.get("helix",false),"phase":opts.get("phase",1),"hits":[],"color":opts.get("color",g.color),"age":0.0,"seed":g.get("seed",false),"boost":g.get("boost",false),"bubble":g.get("bubble",false),"bubble_delay":float(g.get("bubble_delay",1.0)),"homing":g.get("homing",false),"launched":false,"pos":opts.get("pos",p.pos+Vector2.from_angle(angle)*24),"velocity":Vector2.from_angle(angle)*speed,"owner":index,"life":lifetime,"bounce":bounce,"rebounds":0,"dead":false,"bank":g.get("bank",false),"parcel":opts.get("parcel",false),"volley":opts.get("volley",-1),"depth":int(opts.get("depth",0)),"applied_effects":opts.get("applied_effects",[]).duplicate()}
	position = state.pos
	state.cross_turn = float(opts.get("cross_turn",0.0))
	state.cross_turned = false
	state.turn_rate = float(g.get("turn_rate",.7 if state.comet else 1.25))
	state.homing_cone = float(g.get("homing_cone",PI))
	$Visual.modulate = Color(opts.get("color",g.color))
	$Visual.scale = Vector2.ONE * radius/4.0
	$Art.configure(id,bool(opts.get("parcel",false)),bool(opts.get("shard",false)))
	$Art.refresh(state.age,state.velocity)
	$Visual.visible = not $Art.visible
	queue_redraw()
func danger_marked() -> bool:
	return damage >= 1.5 or state.comet or state.gravity or state.seed or state.split or state.clover or state.depth > 0
func _draw() -> void:
	if state == null or state.is_empty(): return
	# Owner colors stay readable even when the weapon sprite uses a different palette.
	var owner_color := Color("64b5ee") if state.owner == 1 else Color("f39545")
	draw_arc(Vector2.ZERO,radius+3,0,TAU,24,owner_color,1.5,true)
	if danger_marked():
		draw_arc(Vector2.ZERO,radius+6,0,TAU,24,Color("fff3b0"),1.5,true)
	if source_player != null and source_player.temporary_relic >= 0 and state.depth > 0:
		for n in range(4): draw_arc(Vector2.ZERO,radius+9,n*PI/2,n*PI/2+PI/4,6,Color("e6a0ff"),2.0,true)
func step(dt: float, arena, enemy) -> void:
	var b = state
	var bounds: Rect2 = arena.projectile_bounds
	if b.dead or b.life <= 0: return
	b.life -= dt
	b.age += dt
	if not b.cross_turned and b.cross_turn != 0.0 and b.age >= .25:
		b.cross_turned = true
		b.velocity = b.velocity.rotated(b.cross_turn)
	# Legacy update order: age, special velocity, then swept movement/collision.
	if b.seed and b.age >= .6 and not b.launched:
		b.velocity = Vector2.ZERO
		var seed_def: Dictionary = source_player.resolved_definition(gun_id)
		if b.pos.distance_to(enemy.state.pos) <= float(seed_def.get("seed_trigger_radius",100.0)) and not arena.line_blocked(b.pos,enemy.state.pos):
			b.launched = true
			b.velocity = (enemy.state.pos-b.pos).normalized()*float(seed_def.get("seed_seek_speed",440.0))
			burst_requested.emit(b.pos,Color(b.color),8)
	if b.boost:
		b.velocity = b.velocity.normalized() * minf(760.0,b.velocity.length()+500.0*dt)
	if b.bubble and b.age >= float(b.get("bubble_delay",1.0)) and not b.launched:
		b.launched = true
		b.velocity = b.velocity.normalized()*480.0
	if b.homing:
		var desired: float = (enemy.state.pos-b.pos).angle()
		var current: float = b.velocity.angle()
		var turn_rate: float = b.turn_rate if absf(wrapf(desired-current,-PI,PI)) <= b.homing_cone else 0.0
		# Radial stars bend only toward a target in their forward 90-degree cone.
		# Rear-facing stars keep spreading instead of all twelve collapsing onto one target.
		if gun_id == 15:
			turn_rate = 1.8 if absf(wrapf(desired-current,-PI,PI)) <= PI/4 else 0.0
		var turn := clampf(wrapf(desired-current,-PI,PI),-turn_rate*dt,turn_rate*dt)
		b.velocity = Vector2.from_angle(current+turn)*b.velocity.length()
	if b.boomerang and b.age > .65:
		var offset: Vector2 = source_player.state.pos-b.pos
		b.velocity += (Vector2.from_angle(offset.angle())*470.0-b.velocity)*dt*4.0
		if offset.length() < 20.0 and b.life > 0 and source_player.state.hp > 0:
			b.life = 0.0
			# 帰還バッテリー: only the bullet actually returning to its owner counts as
			# "recovery" — a hit (see b.hits handling below) or the life timer simply
			# running out never reaches this branch, so neither charges the battery.
			if b.depth == 0: source_player.recover_projectile(gun_id)
	var motion: Vector2 = b.velocity
	if b.helix:
		motion += Vector2(-b.velocity.y,b.velocity.x)/speed*cos(b.age*14.0)*90.0*b.phase
	var steps := maxi(1,ceili(motion.length()*dt/5))
	for n in range(steps):
		if b.dead or b.life <= 0: break
		var previous: Vector2 = b.pos
		b.pos += motion*dt/steps
		if not b.boomerang and (b.pos.x < bounds.position.x or b.pos.x > bounds.end.x or b.pos.y < bounds.position.y or b.pos.y > bounds.end.y or arena.solid(b.pos,radius)):
			if b.bounce > 0:
				b.bounce -= 1
				b.rebounds += 1
				if b.bank: weapon_effect_requested.emit(0,previous,(-b.velocity).angle()+PI/4)
				if b.bank: damage += bank_bonus
				if b.rebounds == 1 and 11 in source_player.relics: b.velocity *= 1.2
				if b.rebounds == 1 and b.depth == 0 and 31 in source_player.relics: damage *= 1.0+source_player.relic_value(31,"rubber_bonus")
				# 反響の種: the *first* bounce of a directly-fired bullet drops a short-lived
				# stationary pool at the bounce point. "echo_seed" in applied_effects makes this
				# resilient even if rebounds==1 could somehow be re-entered; b.depth==0 keeps the
				# pool itself (and any other derived bullet) from ever chaining another one.
				if b.rebounds == 1 and b.depth == 0 and 12 in source_player.relics and "echo_seed" not in b.applied_effects:
					b.applied_effects.append("echo_seed")
					derived_shot_requested.emit(b.owner,previous,12)
				if b.pos.x < bounds.position.x or b.pos.x > bounds.end.x or arena.solid(Vector2(b.pos.x,previous.y),radius): b.velocity.x *= -1
				else: b.velocity.y *= -1
				b.pos = previous
				motion = b.velocity
				burst_requested.emit(b.pos,Color(b.color),4)
			else:
				b.pos = previous
				b.life = 0.0
				burst_requested.emit(b.pos,Color(b.color),7)
				if switcher: weapon_effect_requested.emit(2,b.pos,b.velocity.angle()+PI/4)
		elif b.pos.distance_to(enemy.state.pos) < enemy.radius + radius:
			var pass_key := "back" if b.age > .7 else "out"
			if b.boomerang:
				if pass_key not in b.hits and enemy.hurt(damage,b.volley,false,log_origin): b.hits.append(pass_key)
			else:
				enemy.hurt(damage,b.volley,false,log_origin)
				if switcher: weapon_effect_requested.emit(2,b.pos,b.velocity.angle()+PI/4)
				b.life = 0.0
	position = b.pos
	$Art.refresh(b.age,b.velocity)
	queue_redraw()

# Explicit removal (melee/reset) must never trigger impact/expiry fragments.
func fragments() -> Dictionary:
	if state.dead: return {}
	var scale_damage: float = 1.0+source_player.relic_value(32,"fragment_bonus") if 32 in source_player.relics else 1.0
	if state.parcel: return {"count":5,"speed":240.0,"damage":.35*scale_damage,"life":.7,"color":"#dce9ff"}
	if state.comet: return {"count":12,"speed":260.0,"damage":.45,"life":1.5,"color":state.color}
	if state.split or state.clover:
		return {"count":4 if state.clover else 8,"speed":280.0,"damage":.65*scale_damage,"life":.85 if state.clover else 1.5,"color":state.color}
	return {}
