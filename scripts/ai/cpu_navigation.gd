extends RefCounted
# Bounded arena search. Routes contain fighter-clear segments, not bullet-clear rays.
const CELL := 32.0
const MAX_NODES := 1024

static func segment_clear(arena, from: Vector2, to: Vector2) -> bool:
	if not arena.fighter_bounds.has_point(to): return false
	for n in range(1,ceili(from.distance_to(to)/8.0)+1):
		if arena.solid(from.move_toward(to,n*8.0),18.0): return false
	return true

static func firing_position(arena, point: Vector2, enemy: Vector2, band: Vector2) -> bool:
	var distance := point.distance_to(enemy)
	return distance >= band.x and distance <= band.y and not arena.line_blocked(point,enemy)

static func combat_path(arena, start: Vector2, enemy: Vector2, band: Vector2) -> Array:
	var frontier: Array[Vector2i] = [Vector2i.ZERO]
	var previous := {Vector2i.ZERO: Vector2i.ZERO}
	var cursor := 0
	while cursor < frontier.size() and cursor < MAX_NODES:
		var cell := frontier[cursor]
		cursor += 1
		var point := start+Vector2(cell)*CELL
		if firing_position(arena,point,enemy,band):
			var path: Array = []
			while cell != Vector2i.ZERO:
				path.push_front(start+Vector2(cell)*CELL)
				cell = previous[cell]
			return path
		for offset in [Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT,Vector2i.UP]:
			var next: Vector2i = cell+offset
			if previous.has(next): continue
			if not segment_clear(arena,point,start+Vector2(next)*CELL): continue
			previous[next] = cell
			frontier.append(next)
	return []
