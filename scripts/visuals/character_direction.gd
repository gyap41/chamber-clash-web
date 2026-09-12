extends RefCounted
# Four cardinal views with a small diagonal dead band to avoid flickering.
static func select(direction: Vector2, previous: String = "front") -> String:
	if direction.length_squared() < .0001: return previous
	var axis := direction.normalized()
	var x := absf(axis.x)
	var y := absf(axis.y)
	var was_side := previous == "left" or previous == "right"
	if (was_side and x >= y-.12) or x > y+.12:
		return "left" if axis.x < 0 else "right"
	return "back" if axis.y < 0 else "front"
