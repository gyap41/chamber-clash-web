extends Node2D
# Open threshold; input and progression belong to the exploration controller.
var door_id := ""
var direction := Vector2.RIGHT
var opening_width := 112.0
var available := false
var locked := false
var caption: Label
# Door pieces of the ashen foundry v2 set (docs/art/production/ashen-foundry-v2 stage 4): a stone sill across the
# opening and, while sealed, an iron beam over it. Both are flat floor pieces, so rotating them is fine.
const THRESHOLD = preload("res://assets/stages/ashen-foundry-v2/props/threshold.png")
const BARRIER = preload("res://assets/stages/ashen-foundry-v2/props/barrier.png")
const SILL_DEPTH := 20.0
const BARRIER_DEPTH := 14.0
func configure(entry: Dictionary, destination: String, _theme = null) -> void:
	door_id = entry.id
	position = entry.position
	direction = entry.direction
	opening_width = float(entry.get("width",112.0))
	caption = Label.new()
	caption.text = "F · "+destination
	caption.visible = false
	var inward := -direction
	caption.position = inward*(opening_width*.5+34)-Vector2(90,13)
	if direction.x != 0: caption.position += Vector2(-direction.x*50,opening_width*.25+11)
	caption.add_theme_font_size_override("font_size",14)
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
	caption.visible = value
	queue_redraw()
func set_locked(value: bool) -> void:
	if locked == value: return
	locked = value
	queue_redraw()
func _draw() -> void:
	# The field walls already form the stone returns. Do not cover them with
	# unrelated jamb sprites, or stretch wall coping across the walkable floor.
	# A flush, translucent sill preserves the continuous floor texture beneath it.
	# Long axis along the opening (the tangent of the exit direction).
	draw_set_transform(Vector2.ZERO,Vector2(-direction.y,direction.x).angle())
	draw_texture_rect(THRESHOLD,Rect2(-opening_width*.5,-SILL_DEPTH*.5,opening_width,SILL_DEPTH),false)
	if locked:
		var length := opening_width-6
		draw_texture_rect(BARRIER,Rect2(-length*.5,-BARRIER_DEPTH*.5,length,BARRIER_DEPTH),false)
	draw_set_transform(Vector2.ZERO)
	if available:
		var tangent := Vector2(-direction.y,direction.x)
		draw_circle(-direction*13+tangent*(opening_width*.5-10),2,Color("d5b575"))
