extends Node2D
var definition
func _ready() -> void:
	position = definition.position
	if definition.light_radius > 0:
		var gradient := Gradient.new()
		gradient.colors = PackedColorArray([Color.WHITE,Color(1,1,1,0)])
		var texture := GradientTexture2D.new()
		texture.gradient = gradient
		texture.width = 128
		texture.height = 128
		texture.fill = GradientTexture2D.FILL_RADIAL
		texture.fill_from = Vector2(.5,.5)
		texture.fill_to = Vector2(1,.5)
		var light := PointLight2D.new()
		light.texture = texture
		light.texture_scale = definition.light_radius/64.0
		light.color = definition.light_color
		light.energy = definition.light_energy
		add_child(light)
func _draw() -> void:
	if definition.texture != null: draw_texture_rect(definition.texture,definition.visual_rect,false)
