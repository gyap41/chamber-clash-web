extends Node2D
# Open threshold; input and progression belong to the exploration controller.
var jamb: Texture2D
var door_id := ""
var direction := Vector2.RIGHT
var available := false
var caption: Label
func configure(entry: Dictionary, destination: String, theme = null) -> void:
	if theme != null: jamb = theme.door_jamb
	door_id = entry.id
	position = entry.position
	direction = entry.direction
	caption = Label.new()
	caption.text = destination
	caption.position = Vector2(-180 if direction.x > 0 else 0,-104)
	caption.size = Vector2(180,26)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption.add_theme_color_override("font_color",Color("f3e7c6"))
	caption.add_theme_color_override("font_shadow_color",Color.BLACK)
	caption.add_theme_constant_override("shadow_offset_x",2)
	caption.add_theme_constant_override("shadow_offset_y",2)
	add_child(caption)
func set_available(value: bool) -> void:
	if available == value: return
	available = value
	queue_redraw()
func _draw() -> void:
	var color := Color("ffd680") if available else Color("a4c4ce")
	var edge_x := 6.0 if direction.x > 0 else -54.0
	if jamb != null: draw_texture_rect(jamb,Rect2(edge_x,-80,48,24),false)
	if jamb != null: draw_texture_rect(jamb,Rect2(edge_x,56,48,24),false)
	draw_line(Vector2(edge_x,-54),Vector2(edge_x,54),color,2)
	draw_line(-direction*13,direction*13,color,3)
	draw_line(direction*13,direction*3+Vector2(0,-10),color,3)
	draw_line(direction*13,direction*3+Vector2(0,10),color,3)
	if available: draw_arc(Vector2.ZERO,52,0,TAU,48,color,2)
