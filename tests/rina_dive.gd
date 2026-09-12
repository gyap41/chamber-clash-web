extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var game = load("res://scenes/game/main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	preload("res://tests/helpers/battle.gd").passive_opponents(game)
	game.assign_character(0,0)
	preload("res://tests/helpers/battle.gd").start(game,20)
	var p = game.players[0]
	var command := {"dx":0.0,"dy":0.0,"angle":0.0,"shoot":false}
	for timestep in [1.0/60,1.0/30,.1,.38]:
		p.reset(Vector2(350,450))
		p.state.dir = Vector2.RIGHT
		p.try_dodge()
		var elapsed := 0.0
		while elapsed < .38:
			var dt: float = minf(timestep,.38-elapsed)
			p.step(dt,0,game.players[1],game.arena,false,command)
			elapsed += dt
		assert(absf(p.state.pos.x-350-153.4) < .02)
		assert(p.state.roll < .00001)
	p.reset(Vector2(350,450))
	p.try_dodge()
	p.step(.30,0,game.players[1],game.arena,false,command)
	assert(not p.hurt(1))
	p.step(.02,0,game.players[1],game.arena,false,command)
	assert(p.state.roll > 0 and p.state.inv == 0 and p.hurt(1))
	p.set_character(3)
	assert(is_equal_approx(p.dodge_duration,.26))
	p.set_character(0)
	assert(is_equal_approx(p.dodge_duration,.38))
	print("PASS: Rina dive 153.4px across timesteps, .31s invulnerability, vulnerable landing, other characters .26s")
	game.queue_free()
	quit()
