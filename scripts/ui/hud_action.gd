extends Control
const HudArt = preload("res://scripts/ui/exploration_hud_skin.gd")
const Art = preload("res://scripts/ui/hud_assets.gd")
var action := ""
var compact: bool = false
var charges: int = 0
var cooldown := 0.0
var total := 1.0
var available := true
var art: Texture2D
var ready_flash: float = 0.0
var had_refresh: bool = false
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
	if compact:
		mouse_filter = Control.MOUSE_FILTER_PASS
		tooltip_text = caption+"（"+key_hint+"）"
		hint.hide()
		label.hide()
func refresh(wait: float, duration: float, usable: bool, caption: String) -> void:
	if compact and had_refresh and wait <= 0 and cooldown > 0 and usable: ready_flash = .3
	had_refresh = true
	cooldown = wait
	total = maxf(duration,wait)
	available = usable
	$State.text = caption
	if action == "pulse": charges = int(caption.get_slice(" ",1))
	queue_redraw()
func _process(delta: float) -> void:
	if ready_flash <= 0: return
	ready_flash = maxf(0,ready_flash-delta)
	queue_redraw()
func _draw() -> void:
	if compact:
		var center := Vector2(24,24)
		draw_texture_rect(HudArt.texture("action"),Rect2(1,1,46,46),false)
		if ready_flash > 0: draw_arc(center,21,0,TAU,40,Color(.55,1,.86,ready_flash/.3),2,true)
		if art: draw_texture_rect(art,Rect2(12,12,24,24),false,Color(1,1,1,1 if available else .35))
		if cooldown>0 and total>0: draw_arc(center,22,-PI/2,-PI/2+TAU*clampf(cooldown/total,0,1),40,Color("87d8bd"),2,true)
		if action == "pulse":
			if charges<=4:
				for i in range(charges): draw_rect(Rect2(7+i*9,49,6,4),Color("87d8bd"))
			else: draw_string(ThemeDB.fallback_font,Vector2(17,56),str(charges),HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("87d8bd"))
		return
	var center := Vector2(36,33)
	draw_circle(center,16,Color("303c43"))
	if art: draw_texture_rect(art,Rect2(center-Vector2(12,12),Vector2(24,24)),false,Color(1,1,1,1 if available else .4))
	if cooldown > 0 and total > 0:
		draw_arc(center,17,-PI/2,-PI/2+TAU*clampf(cooldown/total,0,1),32,Color("7cbbda"),2,true)
