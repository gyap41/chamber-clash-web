extends "res://tests/exploration_treasure_supplies.gd"

func run() -> void:
	root.size = Vector2i(1120,800)
	var game = load("res://scenes/game/exploration.tscn").instantiate()
	game.random_floor = true
	game.encounters_enabled = false # Geometry-only fixture; boss fight has its own test.
	root.add_child(game)
	game.set_physics_process(false)
	game.start_exploration(22)
	game.set_pause_reason("focus",false)
	var pre: String = game.floor_data.rooms.keys().filter(func(id): return game.floor_data.rooms[id].role == "antechamber")[0]
	enter(game,pre)
	assert(game.players.size() == 1 and game.exploration.encounter_status == "none")
	game.players[0].state.hp = 2.0
	game.players[0].state.pos = game.arena.field_rect.get_center()
	game.players[0].sync_visual()
	game.fit_field_camera()
	game.refresh_hud()
	await capture("boss-antechamber")
	assert(game.open_bag())
	game.close_bag()
	var door: Dictionary = game.room_data(pre).doors.filter(func(d): return d.id == "north")[0]
	game.players[0].state.pos = door.position
	game.door_armed = true
	assert(game.try_enter_door())
	assert(game.floor_data.rooms[game.exploration.room_id].role == "boss")
	assert(game.players.size() == 1 and game.players[0].state.hp == 2.0)
	assert(game.players[0].state.pos.y > game.arena.field_rect.get_center().y)
	assert(not game.arena.solid(game.players[0].state.pos,game.players[0].radius))
	game.players[0].sync_visual()
	game.fit_field_camera()
	game.refresh_hud()
	await capture("boss-south-entry")
	var back: Dictionary = game.room_data(game.exploration.room_id).doors[0]
	game.players[0].state.pos = back.position
	game.door_armed = true
	assert(game.try_enter_door() and game.exploration.room_id == pre)
	assert(game.players[0].state.hp == 2.0)
	game.queue_free()
	await process_frame
	print("PASS: safe antechamber, bag, boss south entry, return and no free healing")
	quit()
