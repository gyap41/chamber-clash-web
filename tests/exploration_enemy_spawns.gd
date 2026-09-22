extends SceneTree
const Floor = preload("res://scripts/game/exploration_floor.gd")
const Encounter = preload("res://scripts/game/exploration_encounter.gd")
const Navigation = preload("res://scripts/ai/cpu_navigation.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var game = load("res://scenes/game/exploration.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	var checked := 0
	for seed_value in range(10):
		var floor := Floor.generate(seed_value)
		for id in floor.rooms:
			if floor.rooms[id].role != "normal": continue
			var room = floor.catalog[id]
			assert(game.arena.configure_field(room.field,1).is_empty())
			for door in room.doors:
				var positions := Encounter.spawn_positions(game.arena,door.arrival)
				assert(positions.size() == 2)
				assert(positions[0].distance_to(positions[1]) >= 128)
				for point in positions:
					assert(not game.arena.solid(point,18))
					assert(point.distance_to(door.arrival) >= 260)
					assert(not Navigation.combat_path(game.arena,point,door.arrival,Vector2(0,54),16384).is_empty())
				checked += 1
	game.queue_free()
	await process_frame
	print("PASS: enemy spawns and return paths, 10 seeds / %d normal-room entries" % checked)
	quit()
