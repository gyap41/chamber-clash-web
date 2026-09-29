extends "res://tests/authored_rooms_tour.gd"
var crossed := 0
var seen := {}
var edges_seen := {}
func run() -> void:
	game = load("res://scenes/game/authored_map_preview.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	for seed_value in [0,1,2]:
		game.start_exploration(seed_value)
		seen.clear()
		edges_seen.clear()
		if not await visit(): return
		var expected_edges := 0
		for room in game.room_catalog.values(): expected_edges += room.doors.size()
		if edges_seen.size()*2 != expected_edges: fail("An edge, including a cycle, was not traversed"); return
		if seen.size() != game.room_catalog.size(): fail("Unvisited map room"); return
		if game.exploration.room_id != game.start_room: fail("Did not return to entrance"); return
		if game.exploration.status != "active": fail("Art finale must allow return travel"); return
	game.open_map()
	await process_frame
	if game.floor_map == null: fail("Map UI did not open"); return
	game.close_map()
	print("PASS: three generated maps walked over every edge both ways; %d transitions; map UI; return from finale" % crossed)
	game.queue_free()
	await process_frame
	quit()

func visit() -> bool:
	var id: String = game.exploration.room_id
	seen[id] = true
	for door in game.room_catalog[id].doors:
		var pair: Array = [id,door.target_room]
		pair.sort()
		var edge := str(pair)
		if edges_seen.has(edge): continue
		edges_seen[edge] = true
		if not await cross_door(door): return false
		if not seen.has(door.target_room) and not await visit(): return false
		var back: Dictionary = game.door_data(game.exploration.room_id,door.target_door)
		if not await cross_door(back): return false
	return true

func cross_door(door: Dictionary) -> bool:
	var path := route(game.arena.runtime_definition,game.players[0].state.pos,door.position)
	if path.is_empty() or not walk(path): fail("Cannot walk to "+game.exploration.room_id+" "+door.id); return false
	game.door_armed = true
	if not game.try_enter_door() or game.exploration.room_id != door.target_room: fail("Map transition failed"); return false
	crossed += 1
	await process_frame
	return true
