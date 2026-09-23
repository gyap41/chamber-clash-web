extends "res://scripts/visuals/weapon_effect_instance.gd"

func _draw() -> void:
	preload("res://scripts/visuals/boss_cannon_art.gd").impact(self,age,bool(event.get("heavy",false)))
