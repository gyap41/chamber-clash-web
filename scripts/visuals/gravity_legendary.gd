extends Node2D
# All clocks come from combat.step, including Godot's native particle simulation.
const LENS = preload("res://assets/shaders/gravity_lens.gdshader")
var emitters: Array[CPUParticles2D] = []
var lens_material: ShaderMaterial
var effect_age := 0.0
var simulated_time := 0.0
var lens_rect: ColorRect
func _ready() -> void:
	show_behind_parent = true
	var copy = BackBufferCopy.new()
	copy.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	copy.rect = Rect2(-100,-100,200,200)
	add_child(copy)
	lens_material = ShaderMaterial.new();lens_material.shader = LENS
	lens_rect = ColorRect.new();lens_rect.position = Vector2(-90,-90);lens_rect.size = Vector2(180,180)
	lens_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE; lens_rect.material = lens_material
	add_child(lens_rect)
	_make_particles(96,116.0,1.05,false)
	_make_particles(28,72.0,.85,true)

func _make_particles(count: int, radius: float, lifetime: float, mist: bool) -> void:
	var particles = CPUParticles2D.new()
	particles.name = "Mist" if mist else "Infall"
	particles.amount = count; particles.lifetime = lifetime
	particles.local_coords = true;particles.speed_scale = 0.0
	particles.use_fixed_seed = true;particles.seed = 719 if mist else 313
	particles.gravity = Vector2.ZERO;particles.spread = 5.0
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_DIRECTED_POINTS
	var points = PackedVector2Array();var normals = PackedVector2Array()
	for i in range(64):
		var direction = Vector2.from_angle(i*TAU/64.0)
		points.append(direction*radius);normals.append(-direction)
	particles.emission_points=points;particles.emission_normals=normals
	particles.initial_velocity_min = 45.0 if mist else 65.0
	particles.initial_velocity_max = 65.0 if mist else 90.0
	particles.radial_accel_min = -50.0;particles.radial_accel_max = -35.0
	particles.orbit_velocity_min = .12;particles.orbit_velocity_max = .2
	particles.scale_amount_min = .55 if mist else .18
	particles.scale_amount_max = 1.0 if mist else .38
	var gradient = Gradient.new()
	gradient.set_color(0,Color(1,1,1,1));gradient.set_color(1,Color(1,1,1,0))
	var texture = GradientTexture2D.new();texture.width = 24;texture.height = 24
	texture.gradient = gradient;texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from=Vector2(.5,.5);texture.fill_to=Vector2(.5,1)
	particles.texture=texture
	var colors = Gradient.new();colors.offsets=PackedFloat32Array([0,.15,.65,1])
	colors.colors=PackedColorArray([Color(.45,.2,1,0),Color(.55,.25,1,.25 if mist else .65),Color(.8,.65,1,.2 if mist else .9),Color(1,.8,1,0)])
	particles.color_ramp=colors
	var material = CanvasItemMaterial.new();material.blend_mode=CanvasItemMaterial.BLEND_MODE_ADD
	particles.material=material
	add_child(particles);emitters.append(particles)

func advance(age: float, remaining: float, dt: float) -> void:
	effect_age = age
	var strength := clampf(age/.25,0,1)*clampf(remaining/.4,0,1)
	lens_material.set_shader_parameter("effect_age",age)
	lens_material.set_shader_parameter("strength",strength)
	if dt > 0:
		simulated_time += dt
		for particles in emitters:
			if remaining>.3: particles.request_particles_process(dt)
			else: particles.request_particles_process(0,dt)
