extends Node2D
# Temporary layered chest; animation state is presentation only.
var reward: Dictionary
var opening := 0.0
var spawning := 0.0
func _draw() -> void:
	var lift := 0.0 if reward.state == "closed" else -sin((1-clampf(opening/.35,0,1))*PI/2)*12
	var scale_in := 1.0-clampf(spawning/.4,0,1)*.25
	draw_set_transform(Vector2.ZERO,0,Vector2.ONE*scale_in)
	draw_style_box(shadow(),Rect2(-24,2,48,13))
	draw_rect(Rect2(-21,-13,42,26),Color("302c25"))
	draw_rect(Rect2(-19,-11,38,22),Color("84623d"))
	draw_rect(Rect2(-19,-11,38,7),Color("211f1b"))
	draw_rect(Rect2(-22,-20+lift,44,14),Color("ac8450"))
	draw_rect(Rect2(-22,-20+lift,44,3),Color("d6ad6b"))
	for x in [-17,13]: draw_rect(Rect2(x,-12,4,24),Color("b7a470"))
	if reward.state == "closed": draw_rect(Rect2(-4,-9,8,10),Color("dbc477"))
	elif reward.state == "open":
		var icon = preload("res://scripts/catalog/weapon_catalog.gd").art(reward.item)
		draw_texture_rect(icon,Rect2(-16,-40,32,32),false)
	draw_set_transform(Vector2.ZERO)
func shadow() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0,0,0,.35)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	return style
func step(dt: float) -> void:
	opening = maxf(0,opening-dt)
	spawning = maxf(0,spawning-dt)
	queue_redraw()
