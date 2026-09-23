extends Node2D
var kind := "ammo"
func _draw() -> void:
	draw_set_transform(Vector2(0,9),0,Vector2(1,.4))
	draw_circle(Vector2.ZERO,16,Color(0,0,0,.35))
	draw_set_transform(Vector2.ZERO)
	if kind == "ammo":
		var art = preload("res://assets/first-workshop/ammo.png")
		draw_texture_rect(art,Rect2(-18,-23,36,36),false)
	else:
		draw_rect(Rect2(-13,-17,26,29),Color("302d29"))
		draw_rect(Rect2(-11,-15,22,25),Color("b6aa82"))
		draw_rect(Rect2(-6,-21,12,5),Color("766644"),false,2)
		draw_rect(Rect2(-3,-11,6,17),Color("c35346"))
		draw_rect(Rect2(-8,-6,16,6),Color("c35346"))
	draw_string(ThemeDB.fallback_font,Vector2(-17,28),"弾薬" if kind == "ammo" else "回復",HORIZONTAL_ALIGNMENT_LEFT,-1,12)
