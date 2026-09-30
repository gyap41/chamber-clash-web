extends RefCounted
# Visual constructors for the preparation screen; no match state or selection references.

static func panel_at(parent: Node, node_name: String, rect: Rect2) -> Panel:
	var panel := Panel.new()
	panel.name = node_name
	panel.position = rect.position
	panel.size = rect.size
	var style := StyleBoxFlat.new()
	style.bg_color = Color("182534")
	style.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel",style)
	parent.add_child(panel)
	return panel

static func text_at(parent: Node, node_name: String, text: String, rect: Rect2, font_size: int = 18, color: Color = Color("e4edf5")) -> Label:
	var label := Label.new()
	label.name = node_name
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.clip_text = true
	label.max_lines_visible = 2 if rect.size.y >= 40 else 1
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",color)
	# Configure wrapping before text/size: an unwrapped label can otherwise retain
	# its full-text minimum width even after switching to wrapping or ellipsis.
	label.text = text
	label.position = rect.position
	label.size = rect.size
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

static func style_button(button: Button, accent: bool = false) -> void:
	for state_name in ["normal","hover","pressed","disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("69d9c2") if accent else Color("223648")
		if state_name == "hover": style.bg_color = style.bg_color.lightened(.12)
		if state_name == "pressed": style.bg_color = style.bg_color.darkened(.12)
		if state_name == "disabled": style.bg_color = Color("25303d")
		style.set_corner_radius_all(6)
		style.content_margin_left = 10
		style.content_margin_right = 10
		button.add_theme_stylebox_override(state_name,style)
	button.add_theme_color_override("font_color",Color("101925") if accent else Color("e4edf5"))
	button.add_theme_color_override("font_hover_color",Color("101925") if accent else Color("ffffff"))
	button.add_theme_color_override("font_pressed_color",Color("101925") if accent else Color("ffffff"))
	button.add_theme_color_override("font_disabled_color",Color("8c9cab"))
	button.add_theme_font_size_override("font_size",18)
	var focus_style := StyleBoxFlat.new()
	focus_style.bg_color = Color.TRANSPARENT
	focus_style.border_color = Color("cdefff")
	focus_style.set_border_width_all(2)
	button.add_theme_stylebox_override("focus",focus_style)

static func scroll_at(parent: Node, node_name: String, rect: Rect2) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = node_name
	scroll.position = rect.position
	scroll.size = rect.size
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	parent.add_child(scroll)
	var list := VBoxContainer.new()
	list.name = "List"
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation",10)
	scroll.add_child(list)
	return list

static func action_button(parent: Node, name_value: String, caption: String, rect: Rect2, callback: Callable, accent: bool = false) -> Button:
	var button := Button.new()
	button.name = name_value
	button.text = caption
	button.position = rect.position
	button.size = rect.size
	style_button(button,accent)
	button.add_theme_font_size_override("font_size",14)
	button.clip_text = true
	button.pressed.connect(callback)
	parent.add_child(button)
	return button
