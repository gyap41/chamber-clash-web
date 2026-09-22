extends RefCounted
const STEP := 32.0
const RADIUS := 14.0
static func clear_point(field, point: Vector2) -> bool:
	if not field.fighter_bounds.has_point(point) or not field.floor_contains(point): return false
	for wall in field.walls:
		if point.distance_to(point.clamp(wall.position,wall.end)) < RADIUS: return false
	for prop in field.placements:
		if prop.collision == Rect2(): continue
		var rect := Rect2(prop.position+prop.collision.position,prop.collision.size)
		if point.distance_to(point.clamp(rect.position,rect.end)) < RADIUS: return false
	return true
static func clear_segment(field, start: Vector2, finish: Vector2) -> bool:
	for n in range(ceili(start.distance_to(finish)/4.0)+1):
		if not clear_point(field,start.move_toward(finish,n*4.0)): return false
	return true
static func reachable(room) -> bool:
	var start: Vector2 = room.field.spawns[0]
	if not clear_point(room.field,start): return false
	var targets: Array = []
	for door in room.doors: targets.append(door.position); targets.append(door.arrival)
	var pending: Array[Vector2i] = [Vector2i.ZERO]
	var seen := {Vector2i.ZERO:true}
	var cursor := 0
	var limit := mini(16384,(ceili(room.field.field_rect.size.x/STEP)+2)*(ceili(room.field.field_rect.size.y/STEP)+2))
	while cursor < pending.size() and cursor < limit:
		var cell := pending[cursor]
		cursor += 1
		var point := start+Vector2(cell)*STEP
		for index in range(targets.size()-1,-1,-1):
			if point.distance_to(targets[index]) <= STEP and clear_segment(room.field,point,targets[index]): targets.remove_at(index)
		if targets.is_empty(): return true
		for offset in [Vector2i.RIGHT,Vector2i.LEFT,Vector2i.UP,Vector2i.DOWN]:
			var next: Vector2i = cell+offset
			if not seen.has(next) and clear_segment(room.field,point,start+Vector2(next)*STEP):
				seen[next] = true
				pending.append(next)
	return false
