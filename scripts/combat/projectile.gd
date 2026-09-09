extends Node2D
signal burst_requested(pos: Vector2, color: Color, count: int)
signal weapon_effect_requested(row: int, pos: Vector2, angle: float)
var switcher := false
var gun_id := 0
var speed: float = 420.0
@export var lifetime: float = 2.8
@export var comet_blast_radius := 82.0
@export var comet_blast_damage := 1.5
var radius: float = 4.0
var damage: float = 1.0
const Weapons = preload("res://scripts/catalog/weapon_catalog.gd")
var source_player
var state: Dictionary
var log_origin: Dictionary = {}
func launch(player, index: int, id: int = 0, angle: float = 0.0, opts: Dictionary = {}) -> void:
	gun_id = id
	log_origin = {"root":opts.get("root",-1),"kind":opts.get("kind","shot"),"weapon":id,"player":index}
	source_player = player
	var p = player.state
	var g := Weapons.definition(id)
	switcher = g.get("switcher",false)
	speed = opts.get("speed", g.speed)
	damage = opts.get("damage", g.damage)
	if 6 in player.relics:
		speed *= .8
		damage *= 1.15
	if g.get("comet",false): lifetime = 1.45
	elif g.get("gravity",false): lifetime = 1.05
	lifetime = opts.get("life", 3.6 if g.get("seed",false) else (.8 if g.get("clover",false) else (.68 if g.get("split",false) else (1.8 if g.get("boomerang",false) else lifetime))))
	radius = opts.get("radius", 9.0 if opts.get("parcel", false) else (8.0 if g.get("boomerang",false) else (4.0 if g.get("rail",false) else 5.0)))
	if g.get("comet",false): radius = opts.get("radius",11.0)
	elif g.get("gravity",false): radius = opts.get("radius",10.0)
	var special: bool = g.get("split",false) or g.get("comet",false) or g.get("gravity",false) or g.get("boomerang",false) or g.get("seed",false) or g.get("bubble",false) or g.get("clover",false)
	var can_lens: bool = opts.get("can_lens", true)
	var bounce: int = int(g.get("bounce",0)) + (1 if (not special and can_lens and 2 in player.relics) else 0)
	state = {"comet":g.get("comet",false),"gravity":g.get("gravity",false),"split":g.get("split",false),"clover":g.get("clover",false),"boomerang":g.get("boomerang",false),"helix":g.get("helix",false),"phase":opts.get("phase",1),"hits":[],"color":opts.get("color",g.color),"age":0.0,"seed":g.get("seed",false),"boost":g.get("boost",false),"bubble":g.get("bubble",false),"homing":g.get("homing",false),"launched":false,"pos":opts.get("pos",p.pos+Vector2.from_angle(angle)*24),"velocity":Vector2.from_angle(angle)*speed,"owner":index,"life":lifetime,"bounce":bounce,"rebounds":0,"dead":false,"bank":g.get("bank",false),"parcel":opts.get("parcel",false),"volley":opts.get("volley",-1)}
	position = state.pos
	$Visual.modulate = Color(opts.get("color",g.color))
	$Visual.scale = Vector2.ONE * radius/4.0
	$Art.configure(id,bool(opts.get("parcel",false)),bool(opts.get("shard",false)))
	$Art.refresh(state.age,state.velocity)
	$Visual.visible = not $Art.visible
func step(dt: float, arena, enemy) -> void:
	var b = state
	var bounds: Rect2 = arena.projectile_bounds
	if b.dead or b.life <= 0: return
	b.life -= dt
	b.age += dt
	# Legacy update order: age, special velocity, then swept movement/collision.
	if b.seed and b.age >= .6: b.velocity = Vector2.ZERO
	if b.boost:
		b.velocity = b.velocity.normalized() * minf(760.0,b.velocity.length()+500.0*dt)
	if b.bubble and b.age >= 1.0 and not b.launched:
		b.launched = true
		b.velocity = b.velocity.normalized()*480.0
	if b.homing:
		var desired: float = (enemy.state.pos-b.pos).angle()
		var current: float = b.velocity.angle()
		var turn_rate := .7 if b.comet else 1.25
		var turn := clampf(wrapf(desired-current,-PI,PI),-turn_rate*dt,turn_rate*dt)
		b.velocity = Vector2.from_angle(current+turn)*b.velocity.length()
	if b.boomerang and b.age > .65:
		var offset: Vector2 = source_player.state.pos-b.pos
		b.velocity += (Vector2.from_angle(offset.angle())*470.0-b.velocity)*dt*4.0
		if offset.length() < 20.0: b.life = 0.0
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
				if b.bank: damage += .25
				if b.rebounds == 1 and 11 in source_player.relics: b.velocity *= 1.2
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

# Explicit removal (melee/reset) must never trigger impact/expiry fragments.
func fragments() -> Dictionary:
	if state.dead: return {}
	if state.parcel: return {"count":5,"speed":240.0,"damage":.35,"life":.7,"color":"#dce9ff"}
	if state.comet: return {"count":12,"speed":260.0,"damage":.45,"life":1.5,"color":state.color}
	if state.split or state.clover:
		return {"count":4 if state.clover else 8,"speed":280.0,"damage":.65,"life":.85 if state.clover else 1.5,"color":state.color}
	return {}
