extends Node2D
# Manually ticked presentation, independent of combat state and gameplay RNG.
@export var effect_texture: Texture2D = preload("res://assets/effects/weapon-effects.png")
@export var particle_limit := 650
@export var weapon_effect_limit := 40
const DURATIONS := [.22,.32,.2,.26]
const SIZES := [58.0,94.0,54.0,62.0]
var particles: Array = []
var weapon_effects: Array = []
var rings: Array = []
var shake_strength := 0.0
var shake_offset := Vector2.ZERO
@export_range(0.0,1.0) var shake_scale := 1.0
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	rng.randomize()

func burst(pos: Vector2, color: Color, count: int) -> void:
	for i in range(count):
		var velocity := Vector2.from_angle(rng.randf_range(0,TAU))*rng.randf_range(30,180)
		particles.append({"pos":pos,"velocity":velocity,"life":rng.randf_range(.2,.7),"color":color,"size":rng.randf_range(2,5)})
	while particles.size() > maxi(0,particle_limit): particles.pop_front()
	queue_redraw()

func weapon_effect(row: int, pos: Vector2, angle: float = 0.0) -> void:
	if row < 0 or row >= 4: return
	weapon_effects.append({"row":row,"pos":pos,"angle":angle,"age":0.0})
	while weapon_effects.size() > maxi(0,weapon_effect_limit): weapon_effects.pop_front()
	queue_redraw()

func dodge_trail(pos: Vector2, color: Color) -> void:
	if rng.randf() < .35: burst(pos,color,2)

func ring(pos: Vector2, color: Color, expansion: float) -> void:
	rings.append({"pos":pos,"color":color,"expansion":expansion,"age":0.0})
	queue_redraw()

func shake(strength: float) -> void:
	# Legacy assigns the new strength, even when weaker than the previous event.
	shake_strength = strength
	update_shake()

func update_shake() -> void:
	shake_offset = Vector2(rng.randf_range(-shake_strength,shake_strength),rng.randf_range(-shake_strength,shake_strength))*shake_scale if shake_strength > 0.0 else Vector2.ZERO

func clear() -> void:
	particles.clear()
	weapon_effects.clear()
	rings.clear()
	shake_strength = 0.0
	shake_offset = Vector2.ZERO
	queue_redraw()

func step(dt: float) -> void:
	shake_strength = maxf(0.0,shake_strength-30.0*dt)
	update_shake()
	if particles.is_empty() and weapon_effects.is_empty() and rings.is_empty(): return
	for p in particles:
		p.pos += p.velocity*dt
		p.life -= dt
	particles = particles.filter(func(p): return p.life > 0)
	for effect in weapon_effects: effect.age += dt
	weapon_effects = weapon_effects.filter(func(e): return e.age < DURATIONS[e.row])
	for effect in rings: effect.age += dt
	rings = rings.filter(func(e): return e.age < .45)
	queue_redraw()

func _draw() -> void:
	var cell := effect_texture.get_size()/4.0
	for effect in weapon_effects:
		var progress: float = effect.age/DURATIONS[effect.row]
		var frame := mini(3,floori(progress*4))
		var size := Vector2(SIZES[effect.row],SIZES[effect.row]*cell.y/cell.x)
		var alpha := .85*((1.0-progress)/.3 if progress > .7 else 1.0)
		draw_set_transform(effect.pos,effect.angle)
		draw_texture_rect_region(effect_texture,Rect2(-size/2,size),Rect2(Vector2(frame,effect.row)*cell,cell),Color(1,1,1,alpha))
	draw_set_transform(Vector2.ZERO)
	for p in particles:
		var color: Color = p.color
		color.a *= minf(1.0,p.life*3.0)
		draw_line(p.pos,p.pos-p.velocity*.028,color,maxf(1.0,p.size*.45))
	for effect in rings:
		var color: Color = effect.color
		color.a *= 1.0-effect.age/.45
		draw_arc(effect.pos,5.0+effect.expansion*effect.age/.45,0,TAU,96,color,3.0,true)
