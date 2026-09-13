extends SceneTree
var events: Array = []
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var game = load("res://scenes/game/main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	preload("res://tests/helpers/battle.gd").start(game,0)
	game.sound.set_enabled(true)
	game.sound.played.connect(func(kind,_id): events.append(kind))
	for id in [0,9]:
		game.clear_field_objects()
		events.clear()
		var bounds: Rect2 = game.arena.projectile_bounds
		game.spawn_shot(0,id,0,{"pos":Vector2(bounds.end.x-1,bounds.get_center().y)})
		game.shots.back().state.bounce = 0
		game._step_projectiles(.1)
		assert(not events.has("wall_impact"))
		assert(events.count("explosion") == (1 if id == 9 else 0))
	game.free()
	print("PASS: ordinary edge impacts silent, comet explosion once without generic impact")
	quit()
