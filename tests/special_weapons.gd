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
	game.set_physics_process(false)
	var b = setup(game,3)
	assert(game.shots.size() == 3 and game.players[0].weapon().clip == 7)
	var angle: float = b.state.velocity.angle()
	b.step(.1,game.arena,game.players[1])
	assert(is_equal_approx(b.state.velocity.length(),270))
	assert(is_equal_approx(b.state.velocity.angle()-angle,.125))
	# Turning across -PI/PI takes the short route.
	b.state.pos = Vector2(500,100)
	b.state.velocity = Vector2.from_angle(PI-.02)*270
	game.players[1].state.pos = Vector2(100,90)
	b.step(.01,game.arena,game.players[1])
	assert(wrapf(b.state.velocity.angle()-(PI-.02),-PI,PI) > 0)
	b = setup(game,12)
	assert(is_equal_approx(b.state.velocity.length(),130))
	b.step(.1,game.arena,game.players[1])
	assert(is_equal_approx(b.state.velocity.length(),180))
	for i in range(15):
		b.state.pos = Vector2(170,100)
		b.step(.1,game.arena,game.players[1])
	assert(is_equal_approx(b.state.velocity.length(),760))
	b.state.pos = Vector2(210,190)
	b.state.velocity = Vector2(760,0)
	b.step(.1,game.arena,game.players[1])
	assert(b.state.life <= 0 and b.state.pos.x < 240)
	b = setup(game,13)
	assert(game.shots.size() == 3 and game.players[0].weapon().clip == 3)
	var direction: Vector2 = b.state.velocity.normalized()
	b.step(.99,game.arena,game.players[1])
	assert(not b.state.launched and is_equal_approx(b.state.velocity.length(),60))
	game.players[0].equip_slot(0)
	game.players[1].state.pos = Vector2(950,50)
	b.step(.011,game.arena,game.players[1])
	assert(b.state.launched and is_equal_approx(b.state.velocity.length(),480))
	assert(b.state.velocity.normalized().is_equal_approx(direction))
	b.step(.01,game.arena,game.players[1])
	assert(is_equal_approx(b.state.velocity.length(),480))
	b = setup(game,11)
	assert(is_equal_approx(b.state.life,3.6))
	b.step(.59,game.arena,game.players[1])
	assert(b.state.velocity.length() > 0)
	var stop: Vector2 = b.state.pos
	b.step(.011,game.arena,game.players[1])
	assert(b.state.velocity == Vector2.ZERO and b.state.pos == stop)
	b.step(1.0,game.arena,game.players[1])
	assert(b.state.pos == stop)
	game.players[1].state.pos = stop
	b.step(.01,game.arena,game.players[1])
	assert(is_equal_approx(game.players[1].state.hp,6.8) and b.state.life <= 0)
	for id in [3,11,12,13]:
		b = setup(game,id)
		var pos: Vector2 = b.state.pos
		game.paused = true
		game._physics_process(1.1)
		assert(b.state.pos == pos and b.state.age == 0)
		game.paused = false
		# All new projectiles still collide with walls and expire.
		b.state.pos = Vector2(1087,100)
		b.state.velocity = Vector2(270,0)
		b.step(.02,game.arena,game.players[1])
		assert(b.state.life <= 0)
		b = setup(game,id)
		b.state.life = .001
		game._physics_process(.01)
		assert(b not in game.shots)
		b = setup(game,id)
		game.players[1].state.pos = b.state.pos+Vector2(30,0)
		game.players[1].state.angle = PI
		game.players[1].handle_key(KEY_N,1,game.shots,game.players[0],game.arena)
		assert(b.state.dead)
		game._physics_process(.01)
		assert(game.shots.is_empty())
		assert(id in game.Weapons.rarity_pool(game.Weapons.definition(id).rarity))
	game.reset_round()
	assert(game.Weapons.SUPPORTED.size() == 20)
	print("PASS: homing turn/angle wrap, acceleration cap/walls, bubble delay/direction, seed stop/contact, pause/expiry/melee, supported pools")
	game.queue_free()
	quit()
