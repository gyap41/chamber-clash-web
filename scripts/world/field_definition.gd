extends Resource
const StageTheme = preload("res://scripts/world/stage_theme.gd")
const Placement = preload("res://scripts/world/stage_placement.gd")
@export var theme: StageTheme
@export var wall_ids := PackedStringArray()
# Material roles keyed by stable wall IDs: cover, top, face.
@export var wall_materials: Dictionary = {}
@export var placements: Array[Placement] = []
@export var constrain_to_floor := false
# Initial layout only. Fixed resources and future generators produce the same structure.
@export var field_id := ""
@export var field_rect := Rect2(0,0,1120,600)
@export var fighter_bounds := Rect2(60,82,1000,458)
@export var projectile_bounds := Rect2(32,37,1056,533)
@export var floor_color := Color(0.188,0.208,0.196,1)
@export var walls: Array[Rect2] = []
# Optional visual overrides by wall index; collision remains in walls.
@export var wall_textures: Dictionary = {}
@export var wall_face_textures: Dictionary = {}
@export var floor_regions: Array[Rect2] = []
@export var spawns := PackedVector2Array()
@export var supply_points: Dictionary = {}

func validation_errors(participant_count: int = 0, radius: float = 14.0) -> PackedStringArray:
	var errors := PackedStringArray()
	if theme != null: errors.append_array(theme.validation_errors())
	if not wall_ids.is_empty() and wall_ids.size() != walls.size(): errors.append("Wall IDs must match rectangles")
	var seen := {}
	for id in wall_ids:
		if id.is_empty() or seen.has(id): errors.append("Wall IDs must be unique and nonempty")
		seen[id] = true
	for id in wall_materials:
		if not seen.has(id) or wall_materials[id] not in ["cover","top","face"] or theme == null:
			errors.append("Invalid named wall material")
	seen.clear()
	for placement in placements:
		if placement == null:
			errors.append("Null placement")
			continue
		errors.append_array(placement.validation_errors(field_rect))
		if seen.has(placement.placement_id): errors.append("Duplicate placement ID")
		seen[placement.placement_id] = true
	if constrain_to_floor and floor_regions.is_empty(): errors.append("Floor constraint requires floor regions")
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
	for index in wall_textures:
		if not index is int or index < 0 or index >= walls.size():
			errors.append("Invalid wall texture index")
		if not wall_textures[index] is Texture2D: errors.append("Wall texture must be Texture2D")
	for index in wall_face_textures:
		if not index is int or index < 0 or index >= walls.size(): errors.append("Invalid wall face index")
		if not wall_face_textures[index] is Texture2D: errors.append("Wall face must be Texture2D")
	for region in floor_regions:
		if not valid_rect(region) or not field_rect.encloses(region): errors.append("Invalid floor region")
	if not errors.is_empty(): return errors
	for i in range(spawns.size()):
		var point := spawns[i]
		if not point.is_finite() or not fighter_bounds.has_point(point): errors.append("Spawn outside movement bounds")
		if not floor_contains(point): errors.append("Spawn outside floor")
		for placement in placements:
			if placement.collision != Rect2():
				var rect := Rect2(placement.position+placement.collision.position,placement.collision.size)
				if point.distance_to(point.clamp(rect.position,rect.end)) < radius: errors.append("Spawn overlaps placement")
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

func floor_contains(point: Vector2) -> bool:
	if not constrain_to_floor: return true
	for region in floor_regions:
		if region.has_point(point): return true
	return false
