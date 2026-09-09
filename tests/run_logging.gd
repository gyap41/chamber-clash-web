extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var game = load("res://scenes/game/main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.new_match(900)
	var rng_state: int = game.match_state.generator.rng.state
	for n in range(50): game.supplies.weighted_gun()
	assert(game.match_state.generator.rng.state == rng_state)
	preload("res://tests/helpers/battle.gd").start(game,8)
	game.fire(0)
	assert(game.shots.size() == 5)
	var root_id: int = game.shots[0].log_origin.root
	for shot in game.shots: assert(shot.log_origin.root == root_id)
	var enemy = game.players[1]
	game.shots[0].state.pos = enemy.state.pos
	game.shots[0].state.velocity = Vector2.ZERO
	game.shots[0].step(.001,game.arena,enemy)
	game.players[0].add_gun(19)
	game.players[0].state.shot = 0
	game.fire(0)
	game._physics_process(.25)
	game.spawn_shot(0,2,0,{"life":.001})
	game._physics_process(.01)
	game.players[0].add_relic(9)
	assert(game.use_pulse(0))
	for n in range(60): game.telemetry.frame(.02,game.shots.size())
	game.telemetry.file.flush()
	var file := FileAccess.open(game.telemetry.file.get_path(),FileAccess.READ)
	var events: Array = []
	while not file.eof_reached():
		var line := file.get_line()
		if not line.is_empty(): events.append(JSON.parse_string(line))
	assert(events.any(func(e): return e.event == "seed" and e.seed == 900))
	assert(events.any(func(e): return e.event == "projectile" and e.kind == "fragment"))
	assert(events.any(func(e): return e.event == "projectile" and e.kind == "echo"))
	assert(events.any(func(e): return e.event == "projectile" and e.kind == "pulse_relay"))
	assert(events.any(func(e): return e.event == "damage" and e.amount > 0 and e.origin.root == root_id))
	assert(events.any(func(e): return e.event == "performance" and is_equal_approx(e.frame_ms,20)))
	print("PASS: local seed, pellet/root, echo/fragment/pulse identity, actual damage, frame and peak projectile logs")
	game.queue_free()
	quit()
