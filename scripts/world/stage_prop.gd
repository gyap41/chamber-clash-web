extends Node2D
var definition
func _ready() -> void:
	# Sort from the sprite's feet, not its arbitrary authoring origin.
	position = definition.position+Vector2(0,definition.visual_rect.end.y)
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
		light.position = definition.light_offset-Vector2(0,definition.visual_rect.end.y)
		add_child(light)
func _draw() -> void:
	var rect: Rect2 = definition.visual_rect
	rect.position.y -= definition.visual_rect.end.y
	if definition.texture != null: draw_texture_rect(definition.texture,rect,false,definition.tint)

	if definition.wall_flue:
		# Draw over the sprite's open outlet: sealed elbow, with a wall flange.
		var outlet := Vector2(rect.get_center().x,rect.position.y+6)
		draw_set_transform(outlet+Vector2(1,-5),0,Vector2(16,12))
		draw_circle(Vector2.ZERO,1,Color("181d1c"))
		draw_set_transform(Vector2.ZERO)
		draw_style_box(flue_plate(),Rect2(outlet+Vector2(-13,-15),Vector2(26,22)))
		draw_style_box(flue_pipe(),Rect2(outlet+Vector2(-10,-9),Vector2(20,16)))
		draw_line(outlet+Vector2(-7,-5),outlet+Vector2(-7,5),Color("939083"),2)
		draw_line(outlet+Vector2(-10,6),outlet+Vector2(10,6),Color("171d1c"),3)
		for x in [-10,10]:
			draw_circle(outlet+Vector2(x,-12),1,Color("aaa18a"))
func flue_plate() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("454b45")
	style.border_color = Color("827e6b")
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	return style
func flue_pipe() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("4f554e")
	style.border_color = Color("252d2a")
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	return style
