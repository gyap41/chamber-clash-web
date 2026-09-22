extends SceneTree
const Placement = preload("res://scripts/world/stage_placement.gd")
const Room = preload("res://data/rooms/workshop_trial.tres")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var invalid_room = Room.duplicate(true)
	invalid_room.doors.clear()
	invalid_room.doors.append({})
	assert(not invalid_room.validation_errors().is_empty())
	var arena = load("res://scenes/world/arena.tscn").instantiate()
	root.add_child(arena)
	var base_count: int = Room.field.placements.size()
	var field = Room.field.duplicate(true)
	field.field_id = "new-room-without-code-registration"
	var prop := Placement.new()
	prop.placement_id = "test_workbench"
	prop.position = Vector2(700,300)
	prop.texture = field.theme.cover_texture
	prop.collision = Rect2(-20,-10,40,20)
	prop.light_radius = 120
	field.placements.append(prop)
	assert(arena.configure_field(field,1).is_empty())
	assert(arena.solid(Vector2(700,300),2))
	assert(arena.solid(Vector2(70,180),2)) # Dark exterior, even if walls have a gap.
	assert(not arena.solid(Vector2(1050,300),14))
	assert(arena.get_node("StageBackground").get_child_count() == base_count+1)
	assert(arena.get_node("StageBackground").get_child(base_count).get_child(0) is PointLight2D)
	# Replacement props block movement/projectiles using the shared solid query.
	for center in [Vector2(280,211),Vector2(840,410),Vector2(560,302)]:
		assert(arena.solid(center,2))
	assert(not arena.solid(Vector2(245,163),2)) # Old stone corner is now clear.
	# Theme replacement on an unknown room ID must not affect geometry or registration.
	field.theme = field.theme.duplicate(true)
	field.theme.tile_size = 64
	field.theme.wall_top = field.theme.corner
	var rect: Rect2 = arena.get_node("Walls/Wall1").collision_rect()
	assert(arena.configure_field(field,1).is_empty())
	assert(arena.get_node("Walls/Wall1").collision_rect() == rect)
	assert(arena.get_node("Walls/Wall1").tile_size == 64)
	assert(Room.field.theme.tile_size == 48)
	# Named materials survive insertion/reordering when IDs move with their rectangles.
	var wall = field.walls[0]
	field.walls.remove_at(0)
	field.walls.append(wall)
	var id = field.wall_ids[0]
	field.wall_ids.remove_at(0)
	field.wall_ids.append(id)
	assert(arena.configure_field(field,1).is_empty())
	assert(arena.get_node("Walls").get_child(field.walls.size()-1).face_texture != null)
	var invalid = field.duplicate(true)
	invalid.placements.append(invalid.placements[0])
	assert(not arena.configure_field(invalid,1).is_empty())
	assert(arena.runtime_definition.field_id == field.field_id)
	assert(arena.get_node("StageBackground").get_child_count() == base_count+1)
	invalid = field.duplicate(true)
	invalid.theme.tile_size = 0
	assert(not arena.configure_field(invalid,1).is_empty())
	invalid = field.duplicate(true)
	invalid.spawns = PackedVector2Array([Vector2(700,300)])
	assert(not arena.configure_field(invalid,1).is_empty())
	for iteration in range(5):
		assert(arena.configure_field(Room.field,1).is_empty())
		assert(arena.get_node("StageBackground").get_child_count() == base_count)
		assert(not arena.solid(Vector2(700,300),2))
		assert(arena.configure_field(field,1).is_empty())
		assert(arena.get_node("StageBackground").get_child_count() == base_count+1)
	var annex = load("res://data/fields/workshop_annex.tres")
	assert(annex.theme == Room.field.theme and annex.theme.connected_walls and annex.theme.depth_sort)
	assert(arena.configure_field(annex,1).is_empty())
	for center in [Vector2(350,211),Vector2(520,440),Vector2(840,410),Vector2(760,285),Vector2(520,150)]:
		assert(arena.solid(center,2))
	assert(not arena.solid(Vector2(600,200),2)) # Removed legacy stone block.
	assert(not arena.solid(Vector2(70,300),14) and not arena.solid(Vector2(220,300),14))
	arena.queue_free()
	await process_frame
	print("PASS: data-driven theme, stable wall IDs, placement collision/light, exterior constraint, atomic validation and room cleanup")
	quit()
