extends "res://tests/exploration_treasure_supplies.gd"
func run() -> void:
	var game = load("res://scenes/game/exploration.tscn").instantiate()
	game.random_floor = true
	game.authored_campaign = true
	root.add_child(game)
	game.set_physics_process(false)
	game.start_exploration(22)
	game.set_pause_reason("focus",false)
	var normal: Array = game.floor_data.rooms.keys().filter(func(id): return game.floor_data.rooms[id].role == "normal")
	var trials: Array = game.floor_data.rooms.keys().filter(func(id): return game.floor_data.rooms[id].role == "challenge")
	assert(normal.size()>=6 and not trials.is_empty())
	# Finishing an optional trial must not consume the normal-room supply cadence.
	game.exploration.room_state(trials[0]).encounter = "cleared"
	for i in range(6):
		clear_room(game,normal[i])
		var items: Array = game.ExplorationSupplies.entries(game)
		assert(items.filter(func(item): return item.kind=="ammo").size()==(1 if (i+1)%2==0 else 0),"Ammo cadence shifted by optional trial")
		assert(items.filter(func(item): return item.kind=="heal").size()==(1 if (i+1)%3==0 else 0),"Healing cadence shifted by optional trial")
		var saved := items.duplicate(true)
		assert(not game.ExplorationSupplies.ensure(game))
		assert(saved==game.ExplorationSupplies.entries(game),"Rechecking cannot create more supplies")
	game.queue_free()
	await process_frame
	print("PASS: six normal rooms retain ammo/heal cadence after optional trial; no duplicate supplies")
	quit()
