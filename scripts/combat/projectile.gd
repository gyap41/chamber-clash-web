extends Node2D
signal visual_event_requested(event: Dictionary)
var visual_id := 0
var visual_variant := ""
signal burst_requested(pos: Vector2, color: Color, count: int)
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
	visual_id = int(opts.get("visual_weapon",id))
	visual_variant = str(opts.get("visual_variant",""))
	if visual_variant.is_empty() and int(opts.get("depth",0))>0 and str(opts.get("kind","")) not in ["echo","burst"]: visual_variant = "derived"
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
	var scales: Vector2 = preload("res://scripts/combat/relic_effects.gd").scales(player,direct)
	var damage_scale: float = scales.x
	var speed_scale: float = scales.y
	damage *= float(opts.get("damage_scale",damage_scale))
	speed *= float(opts.get("speed_scale",speed_scale))
	if g.get("comet",false): lifetime = 1.45
	elif g.get("gravity",false): lifetime = 1.35
	lifetime = opts.get("life", float(g.get("seed_life",4.8)) if g.get("seed",false) else (.8 if g.get("clover",false) else (.68 if g.get("split",false) else (1.8 if g.get("boomerang",false) else lifetime))))
	radius = opts.get("radius", 9.0 if opts.get("parcel", false) else (8.0 if g.get("boomerang",false) else (4.0 if g.get("rail",false) else 5.0)))
	if g.get("comet",false): radius = opts.get("radius",11.0)
	elif g.get("gravity",false): radius = opts.get("radius",10.0)
	elif g.get("seed",false): radius = opts.get("radius",9.0)
	# Gameplay dimensions are independent of light, smoke and sprite bounds.
	radius = float(opts.get("radius",g.get("parcel_radius",radius) if opts.get("parcel",false) else g.get("projectile_radius",radius)))
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
	preload("res://scripts/combat/weapon_behaviors.gd").dispatch(gun_id,&"launch",{"actor":source_player,"projectile":self})
	position = state.pos
	state.cross_turn = float(opts.get("cross_turn",0.0))
	state.cross_turned = false
	state.turn_rate = float(g.get("turn_rate",.7 if state.comet else 1.25))
	state.homing_cone = float(g.get("homing_cone",PI))
	$Visual.modulate = Color(opts.get("color",g.color))
	$Visual.scale = Vector2.ONE * radius/4.0
	$Art.configure(visual_id,bool(opts.get("parcel",false)),bool(opts.get("shard",false)),visual_variant)
	$Art.refresh(state.age,state.velocity)
	$Visual.visible = not $Art.visible
	queue_redraw()
func step(dt: float, arena, targets) -> void:
	var enemies: Array = targets if targets is Array else ([targets] if targets != null else [])
	var enemy = null
	var nearest := INF
	for target in enemies:
		var distance: float = state.pos.distance_squared_to(target.state.pos)
		if target.state.hp > 0 and distance < nearest:
			nearest = distance
			enemy = target
	var b = state
	var bounds: Rect2 = arena.projectile_bounds
	if b.dead or b.life <= 0: return
	b.life -= dt
	b.age += dt
	if not b.cross_turned and b.cross_turn != 0.0 and b.age >= .25:
		b.cross_turned = true
		b.velocity = b.velocity.rotated(b.cross_turn)
	# Legacy update order: age, special velocity, then swept movement/collision.
	if enemy != null and b.seed and b.age >= .6 and not b.launched:
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
	if enemy != null and b.homing:
		var desired: float = (enemy.state.pos-b.pos).angle()
		var current: float = b.velocity.angle()
		var turn_rate: float = b.turn_rate if absf(wrapf(desired-current,-PI,PI)) <= b.homing_cone else 0.0
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
				preload("res://scripts/combat/weapon_behaviors.gd").dispatch(gun_id,&"bounce",{"actor":source_player,"projectile":self,"pos":previous})
				notify_visual("bounce",previous)
				if b.bank: damage += bank_bonus
				preload("res://scripts/combat/relic_effects.gd").first_bounce(self,previous)
				if b.pos.x < bounds.position.x or b.pos.x > bounds.end.x or arena.solid(Vector2(b.pos.x,previous.y),radius): b.velocity.x *= -1
				else: b.velocity.y *= -1
				b.pos = previous
				motion = b.velocity
				burst_requested.emit(b.pos,Color(b.color),4)
			else:
				b.pos = previous
				b.life = 0.0
				burst_requested.emit(b.pos,Color(b.color),7)
				notify_visual("hit",b.pos)
		else:
			for target in enemies:
				if target.state.hp <= 0 or b.pos.distance_to(target.state.pos) >= target.radius+radius: continue
				var pass_key := ("back" if b.age > .7 else "out")+":"+str(target.participant_id)
				if b.boomerang:
					if pass_key not in b.hits and target.hurt(damage,b.volley,false,log_origin):
						b.hits.append(pass_key)
						preload("res://scripts/combat/weapon_behaviors.gd").dispatch(gun_id,&"hit",{"actor":source_player,"projectile":self,"target":target})
						notify_visual("hit",b.pos)
				else:
					if target.hurt(damage,b.volley,false,log_origin):
						preload("res://scripts/combat/weapon_behaviors.gd").dispatch(gun_id,&"hit",{"actor":source_player,"projectile":self,"target":target})
					notify_visual("hit",b.pos)
					b.life = 0.0
					break

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

func notify_visual(kind: String, pos: Vector2) -> void:
	if kind == "hit" and (state.parcel or state.comet or state.split or state.clover): return
	visual_event_requested.emit({"kind":kind,"weapon":visual_id,"variant":("parcel" if state.parcel else visual_variant),"owner":state.owner,"pos":pos,"angle":state.velocity.angle()})
