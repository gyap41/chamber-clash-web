extends ColorRect
const WORKSHOP_COVER = preload("res://assets/first-workshop/cover.png")
func _draw() -> void:
	draw_texture_rect(WORKSHOP_COVER,Rect2(Vector2.ZERO,size),false)
# ColorRect is both the editable visual and the source of the M1 collision rectangle.
# Axis-aligned walls only: resize with layout handles; do not rotate/scale.
func collision_rect() -> Rect2:
	return Rect2(position,size)
