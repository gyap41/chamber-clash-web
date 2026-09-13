extends Sprite2D
const Visuals = preload("res://scripts/catalog/weapon_visual_catalog.gd")
var profile: Dictionary = {}
const READABILITY = preload("res://assets/shaders/equipment_readability.gdshader")
var shot_color := Color.WHITE
var variant := ""
var samples: Array[Vector2] = []
var last_age := -1.0
var base_scale := Vector2.ONE
var flight_angle := 0.0
var animation_age := 0.0
var flight_speed := 0.0

func configure(id: int, parcel: bool, shard: bool, visual_variant: String = "", color_override: String = "") -> void:
	if not has_node("Trail"):
		var trail = preload("res://scripts/visuals/projectile_trail.gd").new();trail.name="Trail";trail.show_behind_parent=true;add_child(trail)
	profile = Visuals.profile(id)
	variant = visual_variant if not visual_variant.is_empty() else ("parcel" if parcel else ("derived" if shard else ""))
	shot_color = Color(color_override if not color_override.is_empty() else str(profile.get("color","#ffffff")))
	profile.color = shot_color.to_html()
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
	material = null
	if profile.get("readable",false) or profile.has("palette"):
		var shader_material = ShaderMaterial.new();shader_material.shader = READABILITY
		shader_material.set_shader_parameter("shot_color",shot_color)
		shader_material.set_shader_parameter("recolor",1.0 if profile.has("palette") else 0.0)
		shader_material.set_shader_parameter("outline",.7)
		shader_material.set_shader_parameter("outline_step",Vector2.ONE/(texture.get_size()*base_scale))
		material = shader_material
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
	$Trail.queue_redraw()

func draw_trail(canvas: Node2D) -> void:
	# Draw in world units: spinning blades and stretching bubbles must not rotate/stretch their wake.
	canvas.draw_set_transform_matrix(global_transform.affine_inverse())
	var style: String = str(profile.get("trail","none"))
	var color := Color(profile.get("color","#ffffff"))
	var max_length := float(profile.get("trail_length",22.0))
	var width := float(profile.get("trail_width",1.3))
	if style == "aurora":
		draw_aurora(canvas,max_length,width)
	elif style != "none":
		for i in range(1,samples.size()):
			if global_position.distance_to(samples[i-1])>max_length: continue
			var a := samples[i-1];var b := samples[i]
			if a.distance_squared_to(b)<.01: continue
			var strength := float(i)/samples.size()
			color.a = .42*strength
			if style in ["stars","rune"]:
				if i%3==0:
					var r := width*2.0
					canvas.draw_line(a-Vector2(r,0),a+Vector2(r,0),color,1.2,true)
					canvas.draw_line(a-Vector2(0,r),a+Vector2(0,r),color,1.2,true)
					if style=="rune":canvas.draw_polyline(PackedVector2Array([a+Vector2(0,-r*2),a+Vector2(r,0),a+Vector2(0,r*2),a-Vector2(r,0),a-Vector2(0,r*2)]),color,1.0,true)
			elif style in ["dots","leaves","paper","bubble"]:
				if style == "leaves":
					if i%2==0:canvas.draw_colored_polygon(PackedVector2Array([a-Vector2(width*2,0),a-Vector2(0,width),a+Vector2(width*2,0),a+Vector2(0,width)]),color)
				elif style == "paper":
					if i%2==0:canvas.draw_polyline(PackedVector2Array([a-Vector2(width,0),a+Vector2(width,-width),a+Vector2(width*2,width),a+Vector2(0,width*2)]),color,1.0,true)
				else: canvas.draw_circle(a,width*(.5+strength),color)
			elif style == "electric":
				var mid := (a+b)*.5+(b-a).normalized().orthogonal()*2.0*(1 if i%2 else -1)
				canvas.draw_line(a,mid,color,width,true);canvas.draw_line(mid,b,color,width,true)
			elif style == "smoke":
				color = Color(.55,.52,.48,.22*strength)
				canvas.draw_circle(a,width*(2.5-strength),color)
			elif style == "embers": canvas.draw_circle(a,width*strength,color)
			elif style == "prism":
				var side := (b-a).normalized().orthogonal()
				var wave := 0.0
				a += side*wave;b += side*wave
				canvas.draw_line(a,b,Color(shot_color,.6*strength),width*(.6+strength),true)
				canvas.draw_line(a+side*width,b+side*width,Color(shot_color.lightened(.35),.3*strength),1.0,true)
			elif style == "rail":
				canvas.draw_line(a,b,color,width*2.4*strength,true)
				canvas.draw_line(a,b,Color(1,1,1,.75*strength),maxf(.5,width*.65),true)
			else: canvas.draw_line(a,b,color,width*strength,true)
	var flame := float(profile.get("thruster",0.0))
	if flame>0.0 and flight_speed>10.0:
		var direction := Vector2.from_angle(flight_angle)
		var tail := global_position-direction*texture.get_width()*base_scale.x*.36
		var length := flame*(.85+.15*sin(animation_age*53.0))
		var side := direction.orthogonal()*2.4
		canvas.draw_colored_polygon(PackedVector2Array([tail+side,tail-direction*length,tail-side]),Color(1,.46,.12,.85))
		canvas.draw_line(tail,tail-direction*length*.6,Color(1,.94,.65),1.8,true)
	canvas.draw_set_transform_matrix(Transform2D.IDENTITY)

# Clip by travelled distance, then bake one continuous curve: adjacent segments share endpoints.
func aurora_curve(max_length: float) -> PackedVector2Array:
	var reverse_points: Array[Vector2] = []
	if samples.is_empty(): return PackedVector2Array()
	reverse_points.append(samples.back())
	var distance := 0.0
	for i in range(samples.size()-2,-1,-1):
		var previous: Vector2 = reverse_points.back()
		var segment := previous.distance_to(samples[i])
		if segment < .01: continue
		var remaining := max_length-distance
		if remaining <= 0: break
		reverse_points.append(previous.lerp(samples[i],minf(1.0,remaining/segment)))
		distance += minf(segment,remaining)
	if reverse_points.size()<2: return PackedVector2Array()
	reverse_points.reverse()
	var curve := Curve2D.new();curve.bake_interval = 2.5
	for i in range(reverse_points.size()):
		var before := reverse_points[maxi(0,i-1)]
		var after := reverse_points[mini(reverse_points.size()-1,i+1)]
		var tangent := (after-before)*.14
		curve.add_point(reverse_points[i],-tangent,tangent)
	return curve.get_baked_points()

func rainbow_color(t: float) -> Color:
	var palette: Array = profile.get("palette",["#ff657d","#ffa64d","#ffe36a","#7fea8e","#60e7ef","#799bff","#d184ff"])
	var scaled := clampf(t,0,1)*(palette.size()-1)
	var index := mini(int(scaled),palette.size()-2)
	var blend := smoothstep(0.0,1.0,scaled-index)
	return Color(palette[index]).lerp(Color(palette[index+1]),blend)

func draw_aurora(canvas: Node2D, max_length: float, width: float) -> void:
	var points := aurora_curve(max_length)
	if points.size()<2: return
	var lengths: Array[float] = [0.0]
	for i in range(1,points.size()):lengths.append(lengths.back()+points[i-1].distance_to(points[i]))
	var total := maxf(.001,lengths.back())
	# Displace shared points, not each segment separately, so the ribbon cannot split at joints.
	for i in range(points.size()):
		var t := lengths[i]/total
		var tangent := points[mini(i+1,points.size()-1)]-points[maxi(i-1,0)]
		points[i] += tangent.normalized().orthogonal()*sin(t*TAU-animation_age*3.0)*sin(t*PI)*1.8
	for i in range(1,points.size()):
		var t := (lengths[i-1]+lengths[i])*.5/total
		var tint := rainbow_color(t)
		tint = tint.lerp(shot_color,smoothstep(.95,1.0,t))
		var fade := smoothstep(0.0,.1,t)*minf(1.0,total/18.0)
		var body_width := width*(.55+.45*sin(t*PI*.8))
		canvas.draw_line(points[i-1],points[i],Color(tint,.12*fade),body_width*2.7,true)
		canvas.draw_line(points[i-1],points[i],Color(tint,.42*fade),body_width*1.65,true)
		canvas.draw_line(points[i-1],points[i],Color(tint,.88*fade),body_width,true)
