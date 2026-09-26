extends "res://tests/exploration_rooms.gd"
const Gallery = preload("res://scripts/game/workshop_variants_preview.gd")
const Variants = preload("res://scripts/world/workshop_room_variants.gd")
const Reach = preload("res://scripts/world/room_reachability.gd")
func run() -> void:
	root.size = Vector2i(1120,800)
	# Every nonempty opening combination, independent of the seed sample.
	for shape in Variants.NORMAL_SHAPES:
		for mask in range(1,16):
			var sides: Array = []
			for i in range(4):
				if mask & (1 << i): sides.append(Variants.Shell.DIRECTIONS.keys()[i])
			var room = Variants.make_room(shape,sides,shape)
			assert(room.validation_errors().is_empty(),shape)
			assert(Reach.reachable(room),shape+str(sides))
	var catalog := Gallery.build_catalog()
	assert(Rooms.validation_errors(14,catalog).is_empty(),str(Rooms.validation_errors(14,catalog)))
	var game = load("res://scenes/game/workshop_variants_preview.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.set_pause_reason("focus",false)
	for shape in Variants.NORMAL_SHAPES:
		var room = catalog[shape]
		assert(game.switch_field(room.field).is_empty(),shape)
		game.exploration.enter_room(shape,room.field.field_id)
		game.rebuild_doors()
		game.refresh_hud()
		for door in room.doors:
			var positions: Array = game.Encounter.spawn_positions(game.arena,door.arrival,6)
			assert(positions.size() == 6,shape+" enemy spawn "+door.id)
			for point in positions:
				assert(not game.arena.solid(point,20))
		# Regular-size capture: gameplay camera unchanged.
		var center: Vector2 = room.field.field_rect.size*.5
		for offset in [Vector2.ZERO,Vector2(80,40),Vector2(-80,40),Vector2(0,100)]:
			if not game.arena.solid(center+offset,24):
				game.players[0].state.pos = center+offset
				break
		game.players[0].sync_visual()
		game.fit_field_camera()
		await capture("variant-"+shape)
		# Review-only overview: show the full footprint. Never used by gameplay.
		var camera: Camera2D = game.arena.get_node("CombatCamera")
		var dimensions: Vector2 = room.field.field_rect.size
		var scale := minf(1080.0/dimensions.x,580.0/dimensions.y)
		camera.zoom = Vector2.ONE*scale
		camera.position = dimensions*.5-Vector2(560,390)/scale
		camera.force_update_scroll()
		await capture("overview-"+shape)
		game.players[0].state.pos = room.doors[1].position
		game.door_armed = true
		assert(game.try_enter_door(),shape+" transition")
	game.queue_free()
	await process_frame
	print("PASS: 14 shapes x 15 opening combinations; gallery validation; six enemy spawns from both entries; all room transitions; rendered captures when requested")
	quit()
