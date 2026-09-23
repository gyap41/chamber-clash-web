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
	for sample in [{"size":Vector2(880,600),"count":3},{"size":Vector2(1120,600),"count":4},{"size":Vector2(1760,600),"count":5},{"size":Vector2(1120,1080),"count":6}]:
		game.arena.field_rect = Rect2(Vector2.ZERO,sample.size)
		assert(Encounter.composition(game.arena,false) == ["workshop_sentry","workshop_sentry","workshop_sentry"])
		var ids := Encounter.composition(game.arena,true)
		assert(ids.count("quillback") == (1 if sample.count >= 5 else 0))
		assert(ids.size() == sample.count and ids.count("fire_pouch_lizard") == (2 if sample.count >= 5 else 1))
	for seed_value in range(10):
		var floor := Floor.generate(seed_value)
		for id in floor.rooms:
			if floor.rooms[id].role != "normal": continue
			var room = floor.catalog[id]
			assert(game.arena.configure_field(room.field,1).is_empty())
			for door in room.doors:
				var positions := Encounter.spawn_positions(game.arena,door.arrival,Encounter.composition(game.arena,true).size())
				assert(positions.size() == Encounter.composition(game.arena,true).size())
				assert(positions == Encounter.spawn_positions(game.arena,door.arrival,positions.size()))
				for a in range(positions.size()):
					for b in range(a): assert(positions[a].distance_to(positions[b]) >= 160)
				for point in positions:
					assert(not game.arena.solid(point,20))
					assert(point.distance_to(door.arrival) >= 260)
					assert(not Navigation.combat_path(game.arena,point,door.arrival,Vector2(0,54),16384).is_empty())
				checked += 1
	game.queue_free()
	await process_frame
	print("PASS: enemy spawns and return paths, 10 seeds / %d normal-room entries" % checked)
	quit()
