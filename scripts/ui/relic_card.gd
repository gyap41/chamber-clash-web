extends PanelContainer

func _make_custom_tooltip(for_text: String) -> Object:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("101820")
	style.border_color = Color("b3c8dc")
	style.set_border_width_all(1)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel",style)
	var label := Label.new()
	label.custom_minimum_size = Vector2(380,0)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size",18)
	label.add_theme_color_override("font_color",Color.WHITE)
	label.text = for_text
	panel.add_child(label)
	return panel
