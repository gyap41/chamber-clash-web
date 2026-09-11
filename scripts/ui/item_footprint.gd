extends Control
# Code-native footprint thumbnail; shape and full name supplement color.
var shape: Array = [Vector2i.ZERO]
var tint := Color("83deca")
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
func _draw() -> void:
	var bounds := Vector2i.ONE
	for cell in shape: bounds = bounds.max(cell+Vector2i.ONE)
	var unit: float = minf(size.x / bounds.x,size.y / bounds.y)
	var origin: Vector2 = (size-Vector2(bounds)*unit)/2.0
	for cell in shape:
		draw_rect(Rect2(origin+Vector2(cell)*unit,Vector2.ONE*(unit-2)),tint)
