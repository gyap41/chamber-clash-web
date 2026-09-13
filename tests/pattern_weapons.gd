extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func setup(game, id: int):
	game.reset_round()
	preload("res://tests/helpers/battle.gd").start(game,id)
	game.supplies.reset()
	game.players[0].state.pos = Vector2(170,100)
	game.players[0].state.angle = 0.0
	game.players[1].state.pos = Vector2(950,500)
	game.fire(0)
	return game.shots[0]
func run() -> void:
	var game = load("res://scenes/game/main.tscn").instantiate()
	root.add_child(game)
	preload("res://tests/helpers/battle.gd").passive_opponents(game)
	game.set_physics_process(false)
	for id in [2,14]:
		var count := 8 if id == 2 else 4
		var duration := .68 if id == 2 else .8
		var b = setup(game,id)
		assert(is_equal_approx(b.state.life,duration))
		game._physics_process(duration-.01)
		assert(game.shots.size() == 1)
		game._physics_process(.011)
		assert(game.shots.size() == count)
		for i in range(count):
			var shard = game.shots[i]
			assert(is_equal_approx(shard.state.velocity.length(),280))
			assert(is_equal_approx(shard.damage,.65) and shard.radius == 4)
			assert(is_equal_approx(shard.state.life,1.5 if id == 2 else .85))
			assert(is_zero_approx(wrapf(shard.state.velocity.angle()-i*TAU/count,-PI,PI)))
			assert(shard.fragments().is_empty())
		game._physics_process(1.51)
		assert(game.shots.is_empty()) # no recursive fragments
		b = setup(game,id)
		b.state.pos = Vector2(210,190)
		b.state.velocity = Vector2(250,0)
		game._physics_process(.2)
		assert(game.shots.size() == count and game.shots[0].state.pos.x < 240)
		b = setup(game,id)
		game.players[1].state.pos = b.state.pos + Vector2(10,0)
		game._physics_process(.01)
		assert(game.shots.size() == count)
		assert(is_equal_approx(game.players[1].state.hp,8.0-game.Weapons.definition(id).damage))
		b = setup(game,id)
		game.paused = true
		game._physics_process(1.0)
		assert(game.shots.size() == 1 and b.state.age == 0)
		game.paused = false
		b.state.dead = true
		game._physics_process(.01)
		assert(game.shots.is_empty())
	var b = setup(game,7)
	assert(game.shots.size() == 2 and game.players[0].weapon().clip == 11)
	assert(game.shots[0].state.phase == -1 and game.shots[1].state.phase == 1)
	# Isolate the opposing wave offsets from the original spread angles.
	for bullet in game.shots:
		bullet.state.pos = Vector2(170,100)
		bullet.state.velocity = Vector2(340,0)
		bullet.step(.05,game.arena,game.players[1])
	assert(game.shots[0].state.pos.y < 100 and game.shots[1].state.pos.y > 100)
	assert(is_equal_approx(100-game.shots[0].state.pos.y,game.shots[1].state.pos.y-100))
	b.state.pos = Vector2(210,190)
	b.step(.2,game.arena,game.players[1])
	assert(b.state.life <= 0)
	b = setup(game,5)
	assert(b.radius == 13 and is_equal_approx(b.state.life,1.8))
	b.state.pos = Vector2(210,190)
	b.step(.3,game.arena,game.players[1])
	assert(b.state.pos.x > 320 and b.state.life > 0) # through entire wall
	b.state.pos = Vector2(1087,100)
	b.step(.05,game.arena,game.players[1])
	assert(b.state.pos.x > 1088 and b.state.life > 0) # legacy also ignores bounds
	b.state.pos = Vector2(500,100)
	b.state.age = .65
	b.state.velocity = Vector2(390,0)
	game.players[0].state.pos = Vector2(170,100)
	game.players[0].equip_slot(0)
	b.step(.1,game.arena,game.players[1])
	assert(b.state.velocity.x < 390 and absf(b.state.velocity.y) < .001)
	# Return seeks the owner's current position, even after weapon switching.
	game.players[0].state.pos = b.state.pos+Vector2(0,150)
	b.step(.1,game.arena,game.players[1])
	assert(b.state.velocity.y > 0)
	b.state.pos = game.players[0].state.pos+Vector2(10,0)
	b.step(.01,game.arena,game.players[1])
	assert(b.state.life <= 0)
	# Once per legacy pass (age <= .7 / age > .7), not once per substep.
	b = setup(game,5)
	b.state.velocity = Vector2.ZERO
	game.players[1].state.pos = b.state.pos
	b.step(.01,game.arena,game.players[1])
	b.step(.01,game.arena,game.players[1])
	assert(game.players[1].state.hp == 7 and b.state.life > 0)
	b.state.age = .7
	b.step(.001,game.arena,game.players[1])
	b.step(.001,game.arena,game.players[1])
	assert(game.players[1].state.hp == 6 and b.state.hits.size() == 2)
	# A dodged hit does not consume that pass's chance.
	b = setup(game,5)
	b.state.velocity = Vector2.ZERO
	game.players[1].state.pos = b.state.pos
	game.players[1].state.roll = .1
	b.step(.01,game.arena,game.players[1])
	assert(b.state.hits.is_empty())
	game.players[1].state.roll = 0.0
	b.step(.01,game.arena,game.players[1])
	assert(game.players[1].state.hp == 7)
	for id in [2,5,7,14]:
		b = setup(game,id)
		game.players[1].state.pos = b.state.pos+Vector2(30,0)
		game.players[1].state.angle = PI
		game.apply_command(1,{"melee":true})
		game._physics_process(.01)
		assert(game.shots.is_empty())
		assert(id in game.Weapons.rarity_pool(game.Weapons.definition(id).rarity))
	print("PASS: split timer/wall/hit/count/lifetime/no recursion, pause/melee, helix phase/wall, boomerang walls/return/pass hits/dodge")
	game.queue_free()
	quit()
