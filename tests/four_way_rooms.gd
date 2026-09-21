extends "res://tests/exploration_rooms.gd"
const Demo = preload("res://scripts/world/four_way_demo.gd")
func run() -> void:
	var catalog := Demo.catalog()
	var errors := Rooms.validation_errors(14,catalog)
	assert(errors.is_empty(),str(errors))
	# Reject diagonal directions, narrow/nonfinite widths and incompatible links.
	var bad = Demo.catalog()
	bad.crossroads.doors[0].direction = Vector2(1,1)
	assert(not Rooms.validation_errors(14,bad).is_empty())
	for width in [20.0,INF,"wide"]:
		bad = Demo.catalog()
		bad.crossroads.doors[0].width = width
		assert(not Rooms.validation_errors(14,bad).is_empty())
	bad = Demo.catalog()
	bad.crossroads.doors[0].width = 160
	assert(not Rooms.validation_errors(14,bad).is_empty())
	bad = Demo.catalog()
	bad.north.doors[0].direction = Vector2.UP
	assert(not Rooms.validation_errors(14,bad).is_empty())
	root.size = Vector2i(1120,800)
	var game = load("res://scenes/game/exploration.tscn").instantiate()
	game.room_catalog = catalog
	game.start_room = "crossroads"
	root.add_child(game)
	game.set_physics_process(false)
	game.set_pause_reason("focus",false)
	var surface = game.arena.get_node("ConnectedWallSurface")
	for point in [Vector2(112,220),Vector2(1008,220)]:
		assert(surface.faces.any(func(rect): return rect.has_point(point)))
		assert(not surface.tops.any(func(rect): return rect.has_point(point)))
	var player = game.players[0]
	player.hurt(2)
	player.weapon().clip = 2
	player.weapon().reserve = 7
	player.state.dodge = .8
	var before := snapshot(player,game.exploration.inventory)
	for cycle in range(5):
		for side in Demo.DIRECTIONS:
			assert(game.exploration.room_id == "crossroads")
			var door: Dictionary = game.door_data("crossroads",side)
			assert(reachable(game.arena,player.state.pos,door.position))
			# A transverse movement meets the two sides of every opening.
			var tangent := Vector2(-door.direction.y,door.direction.x)
			var actor := {"pos":door.position}
			game.arena.move_fighter(actor,tangent*200)
			assert(absf((actor.pos-door.position).dot(tangent)) <= door.width*.5-player.radius+1)
			player.state.pos = door.position
			player.sync_visual()
			game.refresh_hud()
			if cycle == 0: await capture("four-way-"+side)
			key(game,true)
			assert(game.exploration.room_id == side)
			assert(snapshot(player,game.exploration.inventory) == before)
			assert(game.nearby_door().is_empty())
			var reverse = game.room_data(side).doors[0]
			assert(player.state.pos == reverse.arrival)
			assert(reachable(game.arena,player.state.pos,reverse.position))
			player.state.pos = reverse.position
			assert(not game.try_enter_door()) # Still holding F.
			key(game,false)
			key(game,true)
			key(game,false)
			assert(game.exploration.room_id == "crossroads")
			assert(game.doors.size() == 4)
			assert(snapshot(player,game.exploration.inventory) == before)
	assert(game.exploration.visited_rooms.size() == 5)
	game.start_exploration(21)
	assert(game.exploration.room_id == "crossroads" and game.exploration.visited_rooms.size() == 1)
	game.queue_free()
	await process_frame
	print("PASS: four directions, two opening widths, invalid links rejected, 20 round trips, clearance, reachability, resources and restart")
	quit()
