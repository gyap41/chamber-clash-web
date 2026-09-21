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
	assert(arena.get_node("StageBackground").get_child_count() == 1)
	assert(arena.get_node("StageBackground").get_child(0).get_child(0) is PointLight2D)
	# Theme replacement on an unknown room ID must not affect geometry or registration.
	field.theme = field.theme.duplicate(true)
	field.theme.tile_size = 64
	field.theme.wall_top = field.theme.corner
	var rect: Rect2 = arena.get_node("Walls/Wall4").collision_rect()
	assert(arena.configure_field(field,1).is_empty())
	assert(arena.get_node("Walls/Wall4").collision_rect() == rect)
	assert(arena.get_node("Walls/Wall4").tile_size == 64)
	assert(Room.field.theme.tile_size == 48)
	# Named materials survive insertion/reordering when IDs move with their rectangles.
	var wall = field.walls[3]
	field.walls.remove_at(3)
	field.walls.append(wall)
	var id = field.wall_ids[3]
	field.wall_ids.remove_at(3)
	field.wall_ids.append(id)
	assert(arena.configure_field(field,1).is_empty())
	assert(arena.get_node("Walls").get_child(9).face_texture != null)
	var invalid = field.duplicate(true)
	invalid.placements.append(invalid.placements[0])
	assert(not arena.configure_field(invalid,1).is_empty())
	assert(arena.runtime_definition.field_id == field.field_id)
	assert(arena.get_node("StageBackground").get_child_count() == 1)
	invalid = field.duplicate(true)
	invalid.theme.tile_size = 0
	assert(not arena.configure_field(invalid,1).is_empty())
	invalid = field.duplicate(true)
	invalid.spawns = PackedVector2Array([Vector2(700,300)])
	assert(not arena.configure_field(invalid,1).is_empty())
	for iteration in range(5):
		assert(arena.configure_field(Room.field,1).is_empty())
		assert(arena.get_node("StageBackground").get_child_count() == 0)
		assert(not arena.solid(Vector2(700,300),2))
		assert(arena.configure_field(field,1).is_empty())
		assert(arena.get_node("StageBackground").get_child_count() == 1)
	arena.queue_free()
	await process_frame
	print("PASS: data-driven theme, stable wall IDs, placement collision/light, exterior constraint, atomic validation and room cleanup")
	quit()
