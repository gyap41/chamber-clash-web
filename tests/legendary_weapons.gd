extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func setup(game, id: int = 0):
	game.reset_round()
	preload("res://tests/helpers/battle.gd").start(game,1)
	game.supplies.reset()
	var p = game.players[0]
	p.state.pos = Vector2(170,100)
	p.state.angle = 0.0
	game.players[1].state.pos = Vector2(950,500)
	if id == 0: return null
	p.add_gun(id)
	p.state.shot = 0.0
	game.fire(0)
	return game.shots[0]
func run() -> void:
	var game = load("res://scenes/game/main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	var b = setup(game,9)
	assert(b.radius == 11 and is_equal_approx(b.state.life,1.45))
	assert(game.players[0].weapon().clip == 1)
	b.step(.1,game.arena,game.players[1])
	assert(is_equal_approx(b.state.velocity.angle(),.07) and is_equal_approx(b.state.velocity.length(),245))
	# Expiry blast and fragments; victim outside direct collision radius.
	b.state.pos = Vector2(500,100)
	game.players[1].state.pos = Vector2(560,100)
	b.state.life = 0
	game._physics_process(.01)
	assert(game.shots.size() == 12 and game.players[1].state.hp == 6.5)
	for shard in game.shots:
		assert(is_equal_approx(shard.damage,.45) and is_equal_approx(shard.state.velocity.length(),260))
		assert(is_equal_approx(shard.state.life,1.5) and shard.fragments().is_empty())
	# Direct hit invulnerability prevents immediately stacking the blast damage.
	b = setup(game,9)
	game.players[1].state.pos = b.state.pos+Vector2(10,0)
	game._physics_process(.01)
	assert(game.players[1].state.hp == 6.5 and game.shots.size() == 12)
	# A thin editable wall between blast and target blocks area damage.
	b = setup(game,9)
	var wall = game.arena.get_node("Walls/Wall1")
	var old_pos: Vector2 = wall.position
	var old_size: Vector2 = wall.size
	wall.position = Vector2(500,80)
	wall.size = Vector2(10,60)
	b.state.pos = Vector2(480,100)
	b.state.life = 0
	game.players[1].state.pos = Vector2(540,100)
	game._physics_process(.01)
	assert(game.players[1].state.hp == 8)
	wall.position = old_pos
	wall.size = old_size
	for id in [9,10]:
		b = setup(game,id)
		game.players[1].state.pos = b.state.pos+Vector2(30,0)
		game.players[1].state.angle = PI
		game.players[1].handle_key(KEY_N,1,game.shots,game.players[0],game.arena)
		game._physics_process(.01)
		assert(game.shots.is_empty() and game.wells.is_empty())
	b = setup(game,10)
	assert(b.radius == 10 and is_equal_approx(b.state.life,1.35))
	b.state.pos = Vector2(210,190)
	b.state.velocity = Vector2(230,0)
	game._physics_process(.15)
	assert(game.shots.is_empty() and game.wells.size() == 1)
	assert(game.wells[0].position.x < 240 and game.wells[0].state.owner == 0)
	# Expiry creates one well, even after switching weapon.
	b = setup(game,10)
	game.players[0].equip_slot(0)
	b.state.life = 0
	game._physics_process(.01)
	assert(game.wells.size() == 1)
	game._physics_process(.01)
	assert(game.wells.size() == 1)
	setup(game)
	var well = game.spawn_well(Vector2(500,100),0)
	game.players[0].state.pos = Vector2(550,100)
	game.players[1].state.pos = Vector2(600,100)
	game._physics_process(.1)
	assert(is_equal_approx(game.players[1].state.pos.x,587.5))
	assert(game.players[0].state.pos == Vector2(550,100))
	game.players[1].state.roll = .3
	var before: Vector2 = game.players[1].state.pos
	well.step(.1,game.arena,game.players,game.shots)
	assert(game.players[1].state.pos == before)
	game.players[1].state.roll = 0
	game.players[1].state.pos = Vector2(520,100)
	well.state.tick = 0
	game._physics_process(.01)
	assert(is_equal_approx(game.players[1].state.hp,7.35))
	game._physics_process(.2)
	assert(is_equal_approx(game.players[1].state.hp,7.35))
	game._physics_process(.26)
	assert(is_equal_approx(game.players[1].state.hp,6.7))
	# Pull cannot move the victim through walls; damage is also occluded.
	setup(game)
	wall.position = Vector2(500,80)
	wall.size = Vector2(10,60)
	well = game.spawn_well(Vector2(490,100),0)
	game.players[1].state.pos = Vector2(525,100)
	well.step(.5,game.arena,game.players,game.shots)
	assert(game.players[1].state.pos.x >= 524 and game.players[1].state.hp == 8)
	wall.position = old_pos
	wall.size = old_size
	# Enemy bullet acceleration, friendly exemption, absorption suppresses effects.
	setup(game)
	well = game.spawn_well(Vector2(500,100),0)
	game.spawn_shot(1,0,0,{"pos":Vector2(600,100),"speed":100.0})
	game.spawn_shot(0,0,0,{"pos":Vector2(600,100),"speed":100.0})
	well.step(.1,game.arena,game.players,game.shots)
	assert(is_equal_approx(game.shots[0].state.velocity.x,45) and game.shots[1].state.velocity.x == 100)
	for id in [9,10]: game.spawn_shot(1,id,0,{"pos":Vector2(500,100),"speed":0.0})
	game._physics_process(.01)
	assert(game.shots.size() == 2 and game.wells.size() == 1)
	# Pause/result freeze fields; reset and expiry clean up nodes/state.
	game.paused = true
	var life: float = well.state.life
	game._physics_process(.5)
	assert(well.state.life == life)
	game.paused = false
	game.phase = "result"
	game._physics_process(.5)
	assert(well.state.life == life)
	game.reset_round()
	assert(game.wells.is_empty() and game.arena.get_node("Wells").get_child_count() == 0)
	setup(game)
	well = game.spawn_well(Vector2(500,100),1)
	game._physics_process(3.21)
	assert(game.wells.is_empty())
	assert(game.Weapons.rarity_pool("S") == [8,9,10,15])
	print("PASS: comet turn/blast/occlusion/fragments/direct hit, gravity spawn/pull/dodge/ticks/walls/absorption, pause/result/reset/expiry, S pool")
	game.queue_free()
	quit()
