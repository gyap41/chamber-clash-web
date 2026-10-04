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
var melee_hits: Array = []
var enemy_effects: Array = []
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
	melee_hits.clear()
	enemy_effects.clear()
	shake_strength = 0.0
	shake_offset = Vector2.ZERO
	queue_redraw()

func step(dt: float) -> void:
	for effect in enemy_effects: effect.age += dt
	enemy_effects = enemy_effects.filter(func(effect): return effect.age < .22)
	for hit in melee_hits: hit.age += dt
	melee_hits = melee_hits.filter(func(hit): return hit.age < .16)
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
	draw_enemy_effects()
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
		var palette: Array = e.get("palette",[])
		if e.kind=="fire" and not palette.is_empty():
			for i in range(palette.size()):
				var ray := Vector2.from_angle((i-(palette.size()-1)*.5)*.14)
				canvas_rainbow_ray(ray,Color(palette[i]),progress)
				draw_arc(Vector2.ZERO,12+progress*19,(i-(palette.size()-1)*.5)*.14-.08,(i-(palette.size()-1)*.5)*.14+.08,5,Color(Color(palette[i]),(1-progress)*.65),1.5,true)
		elif not str(e.get("visual_color","")).is_empty():
			var tint := Color(e.visual_color);tint.a = 1.0-progress
			for i in range(5):
				var ray := Vector2.from_angle(i*TAU/5.0)
				draw_line(ray*(3+progress*10),ray*(7+progress*17),tint,2.0,true)
	draw_set_transform(Vector2.ZERO)
	for hit in melee_hits:
		var progress: float = hit.age/.16
		var tint := Color(1.0,.94,.72,1.0-progress)
		for n in range(6):
			var ray := Vector2.from_angle(hit.angle+PI/6+n*TAU/6)
			var reach := (19.0 if n%3 == 0 else 12.0)*(1.0+progress*.6)
			draw_line(hit.pos+ray*progress*7,hit.pos+ray*reach,tint,2.5*(1.0-progress)+.5,true)
		draw_circle(hit.pos,4.0*(1.0-progress),Color(1,1,1,1.0-progress))
	for p in particles:
		var color: Color = p.color
		color.a *= minf(1.0,p.life*3.0)
		draw_line(p.pos,p.pos-p.velocity*.028,color,maxf(1.0,p.size*.45))
	for effect in rings:
		var color: Color = effect.color
		color.a *= 1.0-effect.age/.45
		draw_arc(effect.pos,5.0+effect.expansion*effect.age/.45,0,TAU,96,color,3.0,true)

func draw_enemy_effects() -> void:
	for effect in enemy_effects:
		var t: float = effect.age/.22
		var fade := 1.0-t
		draw_set_transform(effect.pos,effect.angle)
		match str(effect.family):
			"flame":
				var length := 18.0+24.0*t
				draw_colored_polygon(PackedVector2Array([Vector2(-3,-7*fade),Vector2(length,-4*fade),Vector2(length+7,0),Vector2(length,4*fade),Vector2(-3,7*fade)]),Color(1,.42,.1,.65*fade))
				draw_line(Vector2.ZERO,Vector2(length*.65,0),Color(1,.9,.52,fade),4*fade+1,true)
			"quill":
				for offset in effect.get("offsets",[-.44,-.22,0,.22,.44]):
					var ray := Vector2.from_angle(float(offset))
					draw_line(ray*(20+20*t),ray*(35+24*t),Color(1,.9,.61,fade),2*fade+1,true)
			"sentry":
				var reach: float = effect.get("reach",62.0)
				draw_arc(Vector2.ZERO,reach,-1.0+t*.8,.2+t*.8,18,Color(1,.85,.5,.75*fade),4*fade+1,true)
				draw_arc(Vector2.ZERO,reach-5,-.9+t*.8,.1+t*.8,18,Color(1,1,.9,.9*fade),2,true)
			_:
				var tint := Color(1,.48,.13,fade) if effect.family == "flame_hit" else Color(1,.9,.65,fade)
				for n in range(7):
					var ray := Vector2.from_angle(n*TAU/7)
					draw_line(ray*(3+12*t),ray*(8+20*t),tint,2*fade+1,true)
				draw_circle(Vector2.ZERO,5*fade,Color(1,.94,.72,fade))
	draw_set_transform(Vector2.ZERO)

func weapon_event(event: Dictionary) -> void:
	var kind: String = str(event.get("kind",""))
	var weapon: int = int(event.get("weapon",-1))
	if weapon >= 0 and kind in ["fire","hit"]:
		var profile := Visuals.profile(weapon)
		var color_text: String = str(event.get("visual_color",""))
		var tint := Color(color_text if not color_text.is_empty() else str(profile.get("color","#dce9ff")))
		if weapon == 37:
			var palette: Array = profile.get("palette",["#8eefff"])
			for n in range(palette.size()*2):
				var angle := float(event.get("angle",0))+(float(n)/maxf(1,palette.size()*2-1)-.5)*1.0
				if kind == "hit": angle += PI+(n%2-.5)*.7
				particles.append({"pos":event.pos,"velocity":Vector2.from_angle(angle)*(90+n%3*30),"life":.18+n%3*.04,"color":Color(palette[n%palette.size()]),"size":3.0})
			while particles.size() > maxi(0,particle_limit): particles.pop_front()
		else: burst(event.pos,tint,2 if kind == "fire" else 3)
	if kind == "enemy_attack" or (kind == "hit" and event.get("variant","") in ["enemy_fire_seed","enemy_quill"]):
		var effect := event.duplicate(true)
		effect.age = 0.0
		if kind == "hit": effect.family = "flame_hit" if event.variant == "enemy_fire_seed" else "quill_hit"
		enemy_effects.append(effect)
		while enemy_effects.size() > maxi(0,weapon_effect_limit): enemy_effects.pop_front()
		queue_redraw()
		return
	if kind == "melee_hit":
		melee_hits.append({"pos":event.pos,"angle":event.angle,"age":0.0})
		while melee_hits.size() > maxi(0,weapon_effect_limit): melee_hits.pop_front()
		queue_redraw()
		return
	if kind == "cannon_impact":
		var node = preload("res://scripts/visuals/boss_cannon_impact.gd").new()
		add_child(node)
		node.configure(event,{"duration":.64})
		custom_effects.append(node)
		while custom_effects.size() > maxi(0,weapon_effect_limit): custom_effects.pop_front().queue_free()
		return
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
	named_effects.append({"spec":spec,"kind":kind,"owner":event.get("owner"),"token":event.get("token"),"anchor":event.get("anchor") if kind=="reload_start" else null,"weapon":int(event.get("weapon",-1)),"pos":event.get("pos",Vector2.ZERO),"angle":float(event.get("angle",0.0)),"age":0.0,"scale":factor,"palette":profile.get("palette",[]),"visual_color":event.get("visual_color","")})
	while named_effects.size()>maxi(0,weapon_effect_limit): named_effects.pop_front()
	queue_redraw()

func canvas_rainbow_ray(ray: Vector2, tint: Color, progress: float) -> void:
	tint.a = 1.0-progress
	draw_line(ray*6.0,ray*(30.0-progress*8.0),tint,2.3,true)
