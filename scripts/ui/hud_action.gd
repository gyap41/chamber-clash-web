extends Control
const Art = preload("res://scripts/ui/hud_assets.gd")
var action := ""
var cooldown := 0.0
var total := 1.0
var available := true
var art: Texture2D
func configure(key: String, key_hint: String, caption: String) -> void:
	action = key
	art = Art.texture(key)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var hint := Label.new()
	hint.name = "Key"
	hint.text = key_hint
	hint.position = Vector2(0,0)
	hint.size = Vector2(72,17)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size",12)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hint)
	var label := Label.new()
	label.name = "State"
	label.text = caption
	label.position = Vector2(0,49)
	label.size = Vector2(72,20)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size",13)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
func refresh(wait: float, duration: float, usable: bool, caption: String) -> void:
	cooldown = wait
	total = maxf(duration,wait)
	available = usable
	$State.text = caption
	queue_redraw()
func _draw() -> void:
	var center := Vector2(36,33)
	draw_circle(center,16,Color("303c43"))
	if art: draw_texture_rect(art,Rect2(center-Vector2(12,12),Vector2(24,24)),false,Color(1,1,1,1 if available else .4))
	if cooldown > 0 and total > 0:
		draw_arc(center,17,-PI/2,-PI/2+TAU*clampf(cooldown/total,0,1),32,Color("7cbbda"),2,true)
