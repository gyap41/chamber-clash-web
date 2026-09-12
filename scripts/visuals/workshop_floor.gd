extends Node2D
# Presentation only; the field definition remains the authority for geometry.
const FLOOR = preload("res://assets/first-workshop/floor.png")
func _draw() -> void:
	var arena = get_parent().get_parent()
	if arena.runtime_definition == null or arena.runtime_definition.field_id != "duel": return
	draw_texture_rect(FLOOR,arena.field_rect,false,Color(.83,.86,.86))
