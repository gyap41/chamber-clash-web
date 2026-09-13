extends Sprite2D
const Visuals = preload("res://scripts/catalog/weapon_visual_catalog.gd")
var profile: Dictionary = {}
var variant := ""
var samples: Array[Vector2] = []
var last_age := -1.0
var base_scale := Vector2.ONE
var flight_angle := 0.0
var animation_age := 0.0
var flight_speed := 0.0

func configure(id: int, parcel: bool, shard: bool, visual_variant: String = "") -> void:
	profile = Visuals.profile(id)
	variant = visual_variant if not visual_variant.is_empty() else ("parcel" if parcel else ("derived" if shard else ""))
	var spec := Visuals.bullet(id,variant)
	texture = Visuals.texture(str(spec.texture))
	centered = true
	offset = Vector2.ZERO
	var bounds := Visuals.vec(spec.size)
	base_scale = Vector2.ONE*minf(bounds.x/texture.get_width(),bounds.y/texture.get_height())
	if variant.is_empty() and profile.get("fit","") == "stretch": base_scale = bounds/texture.get_size()
	# Fragments retain their source color, but never inherit a full rocket engine or giant wake.
	if not variant.is_empty():
		profile.merge({"motion":"flutter" if variant == "parcel" else "", "thruster":0, "trail_length":20, "trail_width":1, "trail_samples":8, "spin":0},true)
	scale = base_scale
	visible = true
	samples.clear()
	last_age = -1.0

func refresh(age: float, velocity: Vector2) -> void:
	animation_age = age
	flight_speed = velocity.length()
	if flight_speed > .01: flight_angle = velocity.angle()
	rotation = flight_angle+age*float(profile.get("spin",0.0))
	scale = base_scale
	var motion: String = str(profile.get("motion",""))
	if motion == "flutter": rotation += sin(age*19.0)*.18
	elif motion == "pulse": scale *= 1.0+sin(age*7.0)*.06
	elif motion == "bubble":
		var stretch := clampf((flight_speed-100.0)/380.0,0,1)
		scale *= Vector2(1.0+stretch*.35,1.0-stretch*.16)*(1.0+sin(age*9.0)*.04)
	if age != last_age:
		# Sampling each tick also retires a trail when a seed stops moving.
		samples.append(global_position)
		while samples.size()>clampi(int(profile.get("trail_samples",10)),2,24): samples.pop_front()
		last_age = age
	queue_redraw()

func _draw() -> void:
	# Draw in world units: spinning blades and stretching bubbles must not rotate/stretch their wake.
	draw_set_transform_matrix(global_transform.affine_inverse())
	var style: String = str(profile.get("trail","none"))
	var color := Color(profile.get("color","#ffffff"))
	var max_length := float(profile.get("trail_length",22.0))
	var width := float(profile.get("trail_width",1.3))
	if style != "none":
		for i in range(1,samples.size()):
			if global_position.distance_to(samples[i-1])>max_length: continue
			var a := samples[i-1];var b := samples[i]
			if a.distance_squared_to(b)<.01: continue
			var strength := float(i)/samples.size()
			color.a = .42*strength
			if style in ["dots","stars","leaves","paper","bubble"]:
				if style in ["leaves","paper"]: draw_line(a,a+Vector2(width*3,width),color,width,true)
				else: draw_circle(a,width*(.5+strength),color)
			elif style == "electric":
				var mid := (a+b)*.5+(b-a).normalized().orthogonal()*2.0*(1 if i%2 else -1)
				draw_line(a,mid,color,width,true);draw_line(mid,b,color,width,true)
			elif style == "smoke":
				color = Color(.55,.52,.48,.22*strength)
				draw_circle(a,width*(2.5-strength),color)
			elif style == "embers": draw_circle(a,width*strength,color)
			elif style in ["rail","aurora"]:
				draw_line(a,b,color,width*2.4*strength,true)
				draw_line(a,b,Color(1,1,1,.75*strength),maxf(.5,width*.65),true)
			else: draw_line(a,b,color,width*strength,true)
	var flame := float(profile.get("thruster",0.0))
	if flame>0.0 and flight_speed>10.0:
		var direction := Vector2.from_angle(flight_angle)
		var tail := global_position-direction*texture.get_width()*base_scale.x*.36
		var length := flame*(.85+.15*sin(animation_age*53.0))
		var side := direction.orthogonal()*2.4
		draw_colored_polygon(PackedVector2Array([tail+side,tail-direction*length,tail-side]),Color(1,.46,.12,.85))
		draw_line(tail,tail-direction*length*.6,Color(1,.94,.65),1.8,true)
	draw_set_transform_matrix(Transform2D.IDENTITY)
