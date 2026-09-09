extends ColorRect
# ColorRect is both the editable visual and the source of the M1 collision rectangle.
# Axis-aligned walls only: resize with layout handles; do not rotate/scale.
func collision_rect() -> Rect2:
	return Rect2(position,size)
