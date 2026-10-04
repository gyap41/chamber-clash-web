extends RefCounted
# Test arenas and legacy fields may only expose the movement collision interface.
static func solid(arena, point: Vector2, radius: float) -> bool:
	return arena.projectile_solid(point,radius) if arena.has_method("projectile_solid") else arena.solid(point,radius)

static func line_blocked(arena, from: Vector2, to: Vector2, radius: float = 2.0) -> bool:
	return arena.projectile_line_blocked(from,to,radius) if arena.has_method("projectile_line_blocked") else arena.line_blocked(from,to)
