extends Node2D
# One small shader overlay and 18 deterministic motes, no accumulating emitters.
var elapsed := 0.0
var water_material: ShaderMaterial
var center := Vector2.ZERO
var pause_owner: Node
var sunlight := false
func configure(definition, rect: Rect2) -> void:
	var texture: Texture2D = definition.texture
	var area: Rect2 = definition.water_surface
	sunlight = definition.water_sunlight
	center = rect.position+(area.position+area.size*.5)*rect.size
	var atlas_size := texture.get_size()
	var source_rect := Rect2(Vector2.ZERO,atlas_size)
	if texture is AtlasTexture:
		source_rect = texture.region
		atlas_size = texture.atlas.get_size()
	var bounds := Rect2((source_rect.position+area.position*source_rect.size)/atlas_size,area.size*source_rect.size/atlas_size)
	water_material = ShaderMaterial.new()
	water_material.shader = preload("res://scripts/visuals/cistern_water.gdshader")
	water_material.set_shader_parameter("water_bounds",Vector4(bounds.position.x,bounds.position.y,bounds.size.x,bounds.size.y))
	var surface := Sprite2D.new()
	surface.texture = texture
	surface.centered = false
	surface.position = rect.position
	surface.scale = rect.size/texture.get_size()
	surface.material = water_material
	# Overlay must be above the opaque original water, while remaining below the light.
	surface.show_behind_parent = false
	add_child(surface)
	var light_material := CanvasItemMaterial.new()
	light_material.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = light_material
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
	water_material.set_shader_parameter("motion_time",elapsed)
	queue_redraw()
func _draw() -> void:
	if not sunlight: return
	# Fade at both ends and sides. The unseen roof source extends above the old hard edge.
	var origin := center+Vector2(-125,-300)
	var end := center+Vector2(32,70)
	for band in range(5):
		var width := 12.0+band*8.0
		for segment in range(24):
			var t0 := float(segment)/24.0
			var t1 := float(segment+1)/24.0
			var a := origin.lerp(end,t0)
			var b := origin.lerp(end,t1)
			var w0 := width*lerpf(.3,1.0,t0)
			var w1 := width*lerpf(.3,1.0,t1)
			var c0 := Color(1,.91,.67,sin(t0*PI)*.025)
			var c1 := Color(1,.91,.67,sin(t1*PI)*.025)
			draw_polygon(PackedVector2Array([a-Vector2(w0,0),a+Vector2(w0,0),b+Vector2(w1,0),b-Vector2(w1,0)]),PackedColorArray([c0,c0,c1,c1]))
	for n in range(18):
		var t := fposmod(n*.618+elapsed*(.018+n*.0003),1.0)
		var point := origin.lerp(end,t)+Vector2(sin(n*7.1+elapsed*.22)*24*t,0)
		draw_circle(point,.65+float(n%3)*.18,Color(1,.93,.73,sin(t*PI)*.23))
