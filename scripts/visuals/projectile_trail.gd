extends Node2D
# Separate CanvasItem keeps sprite recoloring out of procedural trail geometry.
func _draw() -> void:
	get_parent().draw_trail(self)
