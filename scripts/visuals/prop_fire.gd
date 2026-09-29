extends Node2D
# Bounded decorative particles; no emitter accumulation on revisits.
var elapsed := 0.0
var phase := 0.0
var kind := 0
var source := Vector2.ZERO
var fire_material: ShaderMaterial
var light: PointLight2D
var base_energy := 1.0
var pause_owner: Node
func configure(definition, rect: Rect2, source_light: PointLight2D) -> void:
	kind = definition.fire_kind
	phase = fposmod(definition.position.x*.071+definition.position.y*.037,TAU)
	light = source_light
	base_energy = definition.light_energy
	source = rect.position+rect.size*Vector2(.5,.47 if kind == 2 else .8)
	fire_material = ShaderMaterial.new()
	fire_material.shader = preload("res://scripts/visuals/prop_fire.gdshader")
	fire_material.set_shader_parameter("phase",phase)
	fire_material.set_shader_parameter("strength",1.0 if kind == 2 else .4)
	var sprite := Sprite2D.new()
	sprite.texture = definition.texture
	sprite.centered = false
	sprite.position = rect.position
	sprite.scale = rect.size/definition.texture.get_size()
	sprite.flip_h = definition.flip_h
	sprite.material = fire_material
	add_child(sprite)
	var unlit := CanvasItemMaterial.new()
	unlit.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = unlit
func _ready() -> void:
	var ancestor := get_parent()
	while ancestor != null:
		if "paused" in ancestor:
			pause_owner = ancestor
			break
		ancestor = ancestor.get_parent()
func _process(dt: float) -> void:
	if is_instance_valid(pause_owner) and pause_owner.get("paused"): return
	step(dt)
func step(dt: float) -> void:
	elapsed += dt
	fire_material.set_shader_parameter("motion_time",elapsed)
	var t := elapsed+phase
	if is_instance_valid(light):
		light.energy = base_energy*(1.0+.045*sin(t*5.3)+.025*sin(t*9.7)+.02*sin(t*2.1))
	queue_redraw()
func _draw() -> void:
	if kind == 1: return # Enclosed lamps do not shed embers or smoke into the room.
	for i in range(6 if kind == 2 else 2):
		var age := fposmod(elapsed*.48+phase+float(i)*.618,1.0)
		var p := source+Vector2(sin(float(i)*8.1+age*5.0)*5.0, -age*32.0)
		draw_circle(p,.55,Color(1,.55,.12,sin(age*PI)*.7))
	if kind != 2: return # Furnace smoke exits through its flue.
	for i in range(5):
		var age := fposmod(elapsed*.16+float(i)*.2+phase,1.0)
		var p := source+Vector2(sin(age*4.0+phase)*9.0,-12.0-age*44.0)
		draw_circle(p,2.0+age*6.0,Color(.55,.54,.5,sin(age*PI)*.035))
