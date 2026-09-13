extends Node2D
# Manually ticked presentation, independent of combat state and gameplay RNG.
@export var particle_limit := 650
@export var weapon_effect_limit := 40
const Visuals = preload("res://scripts/catalog/weapon_visual_catalog.gd")
const CustomEffect = preload("res://scripts/visuals/weapon_effect_instance.gd")
var custom_effects: Array = []
var named_effects: Array = []
var particles: Array = []
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
	for node in custom_effects: node.queue_free()
	custom_effects.clear()
	named_effects.clear()
	particles.clear()
	rings.clear()
	shake_strength = 0.0
	shake_offset = Vector2.ZERO
	queue_redraw()

func step(dt: float) -> void:
	shake_strength = maxf(0.0,shake_strength-30.0*dt)
	update_shake()
	for i in range(custom_effects.size()-1,-1,-1):
		if not custom_effects[i].advance(dt):
			custom_effects.pop_at(i).queue_free()
	for e in named_effects:
		e.age += dt
		var actor = e.anchor.get_ref() if e.get("anchor") is WeakRef else null
		if actor != null: e.pos = actor.position
	named_effects = named_effects.filter(func(e): return e.age < float(e.spec.duration))
	if particles.is_empty() and rings.is_empty() and named_effects.is_empty():
		queue_redraw()
		return
	for p in particles:
		p.pos += p.velocity*dt
		p.life -= dt
	particles = particles.filter(func(p): return p.life > 0)
	for effect in rings: effect.age += dt
	rings = rings.filter(func(e): return e.age < .45)
	queue_redraw()

func _draw() -> void:
	for e in named_effects:
		var tex := Visuals.texture(str(e.spec.texture))
		var frames := int(e.spec.get("frames",1))
		var progress := clampf(float(e.age)/float(e.spec.duration),0,1)
		var frame := mini(frames-1,floori(progress*frames))
		var source_size := Vector2(tex.get_width()/float(frames),tex.get_height())
		var bounds := Visuals.vec(e.spec.size)*float(e.get("scale",1.0))
		var size := source_size*minf(bounds.x/source_size.x,bounds.y/source_size.y)
		var anchor := Visuals.vec(e.spec.get("anchor",[.5,.5]))
		draw_set_transform(e.pos,e.angle)
		draw_texture_rect_region(tex,Rect2(-size*anchor,size),Rect2(Vector2(frame*source_size.x,0),source_size),Color(1,1,1,1.0-progress*.6))
	draw_set_transform(Vector2.ZERO)
	for p in particles:
		var color: Color = p.color
		color.a *= minf(1.0,p.life*3.0)
		draw_line(p.pos,p.pos-p.velocity*.028,color,maxf(1.0,p.size*.45))
	for effect in rings:
		var color: Color = effect.color
		color.a *= 1.0-effect.age/.45
		draw_arc(effect.pos,5.0+effect.expansion*effect.age/.45,0,TAU,96,color,3.0,true)

func weapon_event(event: Dictionary) -> void:
	var kind: String = str(event.get("kind",""))
	if kind in ["reload_cancel","reload_complete"]:
		for i in range(custom_effects.size()-1,-1,-1):
			var source: Dictionary = custom_effects[i].event
			if source.get("kind") == "reload_start" and source.get("owner") == event.get("owner") and source.get("token") == event.get("token"):
				custom_effects.pop_at(i).queue_free()
		named_effects = named_effects.filter(func(e): return not (e.kind=="reload_start" and e.owner==event.get("owner") and e.token==event.get("token")))
	# Actor-local default reload motion remains usable without a registered effect.
	var key := "muzzle" if kind == "fire" else kind
	var spec := Visuals.effect(int(event.get("weapon",-1)),key)
	if spec.is_empty(): return
	spec = spec.duplicate(true)
	if kind=="reload_start": spec.duration = maxf(.001,float(event.get("duration",spec.get("duration",.2))))
	if spec.has("scene"):
		var resource = load(str(spec.scene)) if ResourceLoader.exists(str(spec.scene)) else null
		if resource is PackedScene:
			var node = resource.instantiate()
			if node is CustomEffect:
				add_child(node);node.configure(event,spec);custom_effects.append(node)
				while custom_effects.size()>maxi(0,weapon_effect_limit): custom_effects.pop_front().queue_free()
				return
			node.free()
		if not spec.has("texture"): return
	var factor := .55 if kind == "bounce" or kind == "reload_complete" else (2.0 if kind == "split" else 1.0)
	var profile := Visuals.profile(int(event.get("weapon",-1)))
	if kind == "fire": factor *= float(profile.get("muzzle_scale",1.0))
	elif kind in ["hit","split","bounce"]:
		factor *= float(profile.get("impact_scale",1.0))
		var variant_spec: Dictionary = Visuals.data.get("variants",{}).get(str(event.get("variant","")),{})
		factor *= float(variant_spec.get("impact_scale",1.0))
	named_effects.append({"spec":spec,"kind":kind,"owner":event.get("owner"),"token":event.get("token"),"anchor":event.get("anchor") if kind=="reload_start" else null,"weapon":int(event.get("weapon",-1)),"pos":event.get("pos",Vector2.ZERO),"angle":float(event.get("angle",0.0)),"age":0.0,"scale":factor})
	while named_effects.size()>maxi(0,weapon_effect_limit): named_effects.pop_front()
	queue_redraw()
