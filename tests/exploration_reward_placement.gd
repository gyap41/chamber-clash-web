extends "res://tests/exploration_treasure_supplies.gd"
func run() -> void:
	var game = load("res://scenes/game/exploration.tscn").instantiate()
	game.random_floor = true
	root.add_child(game)
	game.set_physics_process(false)
	var checked := 0
	for seed_value in [1,7,22,83,491]:
		game.start_exploration(seed_value)
		game.set_pause_reason("focus",false)
		for id in game.floor_data.rooms:
			var role: String = game.floor_data.rooms[id].role
			if role not in ["treasure","normal"]: continue
			if role == "normal": clear_room(game,id)
			else: enter(game,id)
			var points: Array = []
			var reward: Dictionary = game.Reward.current(game)
			if role == "treasure": assert(not reward.is_empty())
			if not reward.is_empty(): points.append(reward.pos)
			var supplies: Array = game.ExplorationSupplies.entries(game)
			if role == "normal": assert(not supplies.is_empty())
			for supply in supplies: points.append(supply.pos)
			for point in points:
				assert(not game.arena.solid(point,24))
				assert(reachable(game.arena,game.players[0].state.pos,point))
				for other in points:
					if point != other: assert(point.distance_to(other) >= 96)
			checked += 1
	game.queue_free()
	await process_frame
	print("PASS: guaranteed reachable reward/supply placements in ",checked," rooms across 5 seeds")
	quit()
