extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func setup(game, id: int) -> void:
	game.new_match(912)
	preload("res://tests/helpers/battle.gd").start(game,id)
	game.supplies.reset()
	game.players[0].state.pos = Vector2(560,100)
	game.players[0].state.angle = 0.0
	game.players[1].state.pos = Vector2(950,500)
func run() -> void:
	var game = load("res://scenes/game/main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	var p = game.players[0]
	var q = game.players[1]
	setup(game,15)
	game.fire(0)
	assert(game.shots.size() == 8 and p.weapon().clip == 3)
	for i in range(8):
		var b = game.shots[i]
		assert(is_zero_approx(wrapf(b.state.velocity.angle()-i*TAU/8,-PI,PI)))
		assert(b.state.bounce == 1 and is_equal_approx(b.damage,.8))
	# Weapon base, character and relic multiply. Switching cancels the old reload.
	setup(game,21)
	p.set_character(1)
	p.relics = [1]
	p.weapon().clip = 0
	p.start_reload()
	assert(is_equal_approx(p.state.reload,.90*.85*.65))
	p.step(.49,0,q,game.arena)
	assert(p.weapon().clip == 0 and p.state.reload > 0)
	p.step(.01,0,q,game.arena)
	assert(p.weapon().clip == 7 and p.weapon().reserve == 35)
	p.weapon().clip = 6
	p.start_reload()
	p.equip_slot(0)
	assert(p.state.reload == 0 and p.state.reload_slot == -1)
	p.step(2.0,0,q,game.arena)
	assert(p.inventory[1].clip == 6)
	assert(is_equal_approx(p.effective_reload_duration(),1.35*.85*.65))
	# Reload takes its duration at start; acquired gear affects the next reload.
	setup(game,4)
	p.set_character(0)
	p.weapon().clip = 1
	p.start_reload()
	assert(is_equal_approx(p.state.reload,1.45*1.1))
	p.relics = [1,21]
	p.step(1.5,0,q,game.arena)
	assert(p.weapon().clip == 1 and p.state.reload > 0)
	p.step(.1,0,q,game.arena)
	assert(p.weapon().clip == 4 and p.weapon().reserve == 17)
	# Unspecified weapons retain 1.15 seconds and actual reload flips the spanner.
	setup(game,18)
	p.weapon().clip = 5
	p.start_reload()
	assert(is_equal_approx(p.state.reload,1.15*1.1))
	p.step(1.27,0,q,game.arena)
	assert(p.weapon().clip == 6 and p.weapon().mode == 1)
	p.start_reload()
	assert(p.state.reload == 0 and p.weapon().mode == 1)
	print("PASS: eight radial angles/ammo, weapon-character-relic reload, timing, switch cancellation, snapshot, expanded small magazine, default reload and mode")
	game.queue_free()
	quit()
