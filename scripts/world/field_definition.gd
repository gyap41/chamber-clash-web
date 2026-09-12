extends Resource
# Initial layout only. Fixed resources and future generators produce the same structure.
@export var field_id := ""
@export var field_rect := Rect2(0,0,1120,600)
@export var fighter_bounds := Rect2(60,82,1000,458)
@export var projectile_bounds := Rect2(32,37,1056,533)
@export var floor_color := Color(0.188,0.208,0.196,1)
@export var walls: Array[Rect2] = []
@export var spawns := PackedVector2Array()
@export var supply_points: Dictionary = {}

func validation_errors(participant_count: int = 0, radius: float = 14.0) -> PackedStringArray:
	var errors := PackedStringArray()
	if participant_count < 0 or not is_finite(radius) or radius <= 0: errors.append("Invalid participant clearance")
	if field_id.is_empty(): errors.append("field_id is required")
	for bounds in [field_rect,fighter_bounds,projectile_bounds]:
		if not valid_rect(bounds): errors.append("Bounds must be finite rectangles with positive size")
	if not errors.is_empty(): return errors
	if not field_rect.encloses(fighter_bounds) or not field_rect.encloses(projectile_bounds):
		errors.append("Movement and projectile bounds must be inside the field")
	if spawns.is_empty() or spawns.size() < participant_count: errors.append("Not enough participant spawns")
	for wall in walls:
		if not valid_rect(wall) or not field_rect.encloses(wall): errors.append("Invalid wall rectangle")
	if not errors.is_empty(): return errors
	for i in range(spawns.size()):
		var point := spawns[i]
		if not point.is_finite() or not fighter_bounds.has_point(point): errors.append("Spawn outside movement bounds")
		for wall in walls:
			if point.distance_to(point.clamp(wall.position,wall.end)) < radius: errors.append("Spawn overlaps a wall")
		for j in range(i):
			if point.distance_to(spawns[j]) < radius*2: errors.append("Participant spawns overlap")
	for group in supply_points:
		if not group is String or group.is_empty() or group in [".",".."] or group.validate_node_name() != group:
			errors.append("Invalid supply group name")
		if not supply_points[group] is PackedVector2Array:
			errors.append("Supply groups require PackedVector2Array")
			continue
		for point in supply_points[group]:
			if not point.is_finite() or not fighter_bounds.has_point(point): errors.append("Supply point outside movement bounds")
	# Occupied supply points are legal: the existing spawn policy tries another marker.
	return errors

static func valid_rect(rect: Rect2) -> bool:
	return rect.position.is_finite() and rect.size.is_finite() and rect.end.is_finite() and rect.size.x > 0 and rect.size.y > 0
