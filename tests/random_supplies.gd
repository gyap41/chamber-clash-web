extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var game = load("res://scenes/game/main.tscn").instantiate()
	root.add_child(game)
	preload("res://tests/helpers/battle.gd").passive_opponents(game)
	game.set_physics_process(false)
	preload("res://tests/helpers/battle.gd").start(game)
	var s = game.supplies
	var positions := {}
	for trial in range(24):
		s.reset()
		game.supply_generator.rng.seed = trial
		game.remaining = 20.0 if trial % 2 else game.round_duration
		for group in ["Ammo","Weapons","Relics","Legendary"]:
			s.spawn_group(group,"ammo")
		assert(s.items.size() == 4)
		for item in s.items:
			assert(game.arena.safe_rect(game.arena_inset(),Vector2(55,45)).has_point(item.position))
			assert(not game.arena.solid(item.position,30))
			assert(item.position in s.reachable)
			for other in s.items:
				assert(item == other or item.position.distance_to(other.position) >= 80)
			positions[item.position] = true
		s.reset()
		game.supply_generator.rng.seed = 123
		s.spawn_group("Ammo","ammo")
		var first: Vector2 = s.items[0].position
		s.reset()
		game.supply_generator.rng.seed = 123
		s.spawn_group("Ammo","ammo")
		assert(s.items[0].position == first)
	assert(positions.size() > 24)
	print("PASS: random supply diversity, seeded replay, safe-zone/wall clearance and spacing")
	game.queue_free()
	quit()
