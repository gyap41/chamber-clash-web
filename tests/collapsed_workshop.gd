extends "res://tests/exploration_rooms.gd"
const Demo = preload("res://scripts/world/collapsed_workshop_demo.gd")
const Reachability = preload("res://scripts/world/room_reachability.gd")

func run() -> void:
	root.size = Vector2i(1120,800)
	var catalog := Demo.catalog()
	var errors := Rooms.validation_errors(14,catalog)
	assert(errors.is_empty(),str(errors))
	for room in catalog.values(): assert(Reachability.reachable(room))
	var game = load("res://scenes/game/collapsed_workshop_preview.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.set_pause_reason("focus",false)
	var player = game.players[0]
	assert(game.arena.solid(Vector2(430,320),14))
	assert(game.arena.solid(Vector2(980,180),14))
	assert(not game.arena.solid(Vector2(600,400),14))
	assert(game.arena.line_blocked(Vector2(370,320),Vector2(490,320)))
	assert(not game.arena.line_blocked(Vector2(500,400),Vector2(700,400)))
	assert(reachable(game.arena,player.state.pos,Vector2(135,370)))
	assert(reachable(game.arena,player.state.pos,Vector2(910,510)))
	player.state.pos = Vector2(555,345)
	player.sync_visual()
	game.fit_field_camera()
	game.refresh_hud()
	await capture("collapsed-workshop")
	player.state.pos = Vector2(430,270)
	player.sync_visual()
	game.fit_field_camera()
	await capture("collapsed-workshop-behind-pillar")
	var count: int = game.arena.runtime_definition.placements.size()
	player.state.pos = game.room_data("collapsed_workshop").doors[0].position
	game.door_armed = true
	assert(game.try_enter_door() and game.exploration.room_id == "collapse_approach")
	player.state.pos = game.room_data("collapse_approach").doors[0].position
	game.door_armed = true
	assert(game.try_enter_door() and game.exploration.room_id == "collapsed_workshop")
	assert(game.arena.runtime_definition.placements.size() == count)
	game.queue_free()
	await process_frame
	print("PASS: collapsed room validation, both door paths, annex access, pillar/rubble collision, roundtrip without duplicate placements")
	quit()
