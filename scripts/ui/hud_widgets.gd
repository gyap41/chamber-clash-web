extends RefCounted
const Art = preload("res://scripts/ui/hud_assets.gd")
# Visual constructors only; no mode or actor references.
static func box(parent: Node, title: String, rect: Rect2) -> Panel:
	var panel := Panel.new()
	panel.name = title
	panel.position = rect.position
	panel.size = rect.size
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = Color("192126")
	style.border_color = Color("44535b")
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	panel.add_theme_stylebox_override("panel",style)
	var background := Art.optional_texture("panel")
	if background:
		var textured := StyleBoxTexture.new()
		textured.texture = background
		textured.texture_margin_left = 8
		textured.texture_margin_top = 8
		textured.texture_margin_right = 8
		textured.texture_margin_bottom = 8
		panel.add_theme_stylebox_override("panel",textured)
	parent.add_child(panel)
	return panel

static func label(parent: Node, title: String, rect: Rect2, font_size: int = 16) -> Label:
	var item := Label.new()
	item.name = title
	item.position = rect.position
	item.size = rect.size
	item.add_theme_font_size_override("font_size",font_size)
	item.add_theme_color_override("font_color",Color("e5edf0"))
	item.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(item)
	return item

static func button(parent: Node, title: String, rect: Rect2, caption: String, callback: Callable) -> Button:
	var item := Button.new()
	item.name = title
	item.position = rect.position
	item.size = rect.size
	item.text = caption
	item.focus_mode = Control.FOCUS_NONE
	item.add_theme_font_size_override("font_size",14)
	item.pressed.connect(callback)
	parent.add_child(item)
	return item
