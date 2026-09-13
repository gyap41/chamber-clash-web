extends "res://scripts/visuals/weapon_effect_instance.gd"
func _draw() -> void:
	draw_arc(Vector2.ZERO,8+age*20,0,TAU,16,Color.CYAN,1.0,true)
