extends "res://tests/exploration_rooms.gd"
var reached := {}
var captured_shapes := {}
func walk(game, id: String) -> void:
	reached[id] = true
	var shape: String = game.floor_data.rooms[id].get("shape","standard")
	if not captured_shapes.has(shape):
		captured_shapes[shape] = true
		var position: Vector2 = game.players[0].state.pos
		game.players[0].state.pos = game.arena.field_rect.get_center()
		game.players[0].sync_visual()
		game.fit_field_camera()
		game.refresh_hud()
		assert(game.arena.get_node("CombatCamera").zoom == Vector2.ONE)
		await capture("variant-"+shape)
		game.players[0].state.pos = position
		game.players[0].sync_visual()
		game.fit_field_camera()
	for door in game.room_data(id).doors:
		if reached.has(door.target_room): continue
		game.players[0].state.pos = door.position
		key(game,false); key(game,true); key(game,false)
		assert(game.exploration.room_id == door.target_room)
		await walk(game,door.target_room)
		var back: Dictionary = game.door_data(door.target_room,door.target_door)
		game.players[0].state.pos = back.position
		key(game,false); key(game,true); key(game,false)
		assert(game.exploration.room_id == id)
func run() -> void:
	root.size = Vector2i(1120,800)
	var title = load("res://scenes/ui/title.tscn").instantiate()
	root.add_child(title)
	await capture("random-title")
	title.start_random_floor()
	var game = root.get_node("Exploration")
	# Geometry/resource traversal fixture. Encounter lifecycle has its own test.
	game.encounters_enabled = false
	game.set_physics_process(false)
	game.start_exploration(22)
	await process_frame
	await process_frame
	game.set_pause_reason("focus",false)
	assert(game.floor_data.catalog.size() == 11)
	assert(game.floor_data.seed == 22)
	var first_layout: Dictionary = game.floor_data.rooms.duplicate(true)
	var player = game.players[0]
	player.hurt(2)
	player.weapon().clip = 2
	player.state.pos = game.room_loot()[1].pos
	assert(game.try_collect_loot())
	player.state.pos = Vector2(170,300)
	player.sync_visual()
	var before := snapshot(player,game.exploration.inventory)
	assert(game.open_map() and game.paused)
	var visible: Dictionary = game.floor_map.visible_rooms()
	assert(visible.size() == 1+game.room_data(game.start_room).doors.size())
	game.set_pause_reason("focus",true)
	game.close_map()
	assert(game.paused)
	game.set_pause_reason("focus",false)
	game.refresh_hud()
	await capture("random-start")
	await walk(game,game.start_room)
	assert(reached.size() == 11 and game.exploration.visited_rooms.size() == 11)
	assert(snapshot(player,game.exploration.inventory) == before)
	assert(game.loot_nodes.size() == 1 and game.exploration.collected_loot.size() == 1)
	assert(game.open_map())
	await capture("random-map")
	var event := InputEventKey.new()
	event.keycode = KEY_M
	event.pressed = true
	root.push_input(event)
	assert(game.floor_map == null and not game.paused)
	event.pressed = false
	root.push_input(event)
	game.start_exploration(22)
	assert(game.floor_data.rooms == first_layout and game.exploration.visited_rooms.size() == 1)
	assert(game.loot_nodes.size() == 2 and game.exploration.collected_loot.is_empty())
	game.start_exploration(23)
	assert(game.floor_data.rooms != first_layout)
	game.queue_free()
	await process_frame
	print("PASS: title entry, generated floor traversal, resources, map reveal/pause/input, seeded retry")
	quit()
