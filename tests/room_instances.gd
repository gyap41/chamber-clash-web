extends "res://tests/exploration_rooms.gd"
const Progress = preload("res://scripts/game/exploration_state.gd")
const Loot = preload("res://scripts/game/exploration_loot.gd")
func run() -> void:
	# Two instances of one template own distinct encounter and pickup identities.
	var progress := Progress.new(81)
	progress.enter_room("floor1_room1","workshop_trial")
	progress.encounter_status = "cleared"
	var first := Loot.entries(progress.room_id,"workshop_trial")
	assert(Loot.collect(first[1],progress).acquired)
	progress.enter_room("floor1_room2","workshop_trial")
	assert(progress.encounter_status == "none")
	var second := Loot.entries(progress.room_id,"workshop_trial")
	assert(first[1].id != second[1].id and not progress.collected_loot.has(second[1].id))
	assert(Loot.collect(second[1],progress).acquired)
	assert(not Loot.collect(second[1],progress).acquired)
	progress.enter_room("floor1_room1","workshop_trial")
	assert(progress.encounter_status == "cleared" and progress.collected_loot.size() == 2)
	assert(Progress.new(81).room_states.is_empty())
	# Catalog keys are instance IDs; field IDs remain template IDs through real transitions.
	var catalog := {}
	var mapping := {"workshop_trial":"floor1_room1","workshop_annex":"floor1_room2"}
	for template_id in Rooms.ROOMS:
		var room = Rooms.ROOMS[template_id].duplicate(true)
		for door in room.doors: door.target_room = mapping[door.target_room]
		catalog[mapping[template_id]] = room
	assert(Rooms.validation_errors(14,catalog).is_empty())
	var game = load("res://scenes/game/exploration.tscn").instantiate()
	game.room_catalog = catalog
	game.start_room = "floor1_room1"
	root.add_child(game)
	game.set_physics_process(false)
	game.set_pause_reason("focus",false)
	assert(game.exploration.visited_rooms.keys() == ["floor1_room1"])
	assert(game.room_loot().size() == 2)
	game.players[0].state.pos = game.room_loot()[1].pos
	assert(game.try_collect_loot())
	game.exploration.encounter_status = "cleared"
	for crossing in range(4):
		game.players[0].state.pos = game.room_data(game.exploration.room_id).doors[0].position
		key(game,false)
		key(game,true)
		assert(game.exploration.encounter_status == ("none" if crossing % 2 == 0 else "cleared"))
	assert(game.loot_nodes.size() == 1)
	assert(game.exploration.room_states.size() == 2)
	game.start_exploration(81)
	assert(game.loot_nodes.size() == 2 and game.exploration.room_states.size() == 1)
	assert(game.exploration.encounter_status == "none")
	game.queue_free()
	await process_frame
	print("PASS: instance/template identity, independent encounter/pickups, real transitions, revisit and restart")
	quit()
