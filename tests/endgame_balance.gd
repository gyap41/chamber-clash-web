extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func setup(game, weapon: int) -> void:
	game.new_match(42)
	preload("res://tests/helpers/battle.gd").start(game,weapon)
	game.supplies.reset()
	game.players[0].state.pos = Vector2(170,100)
	game.players[0].state.angle = 0.0
	game.players[1].state.pos = Vector2(600,100)
func run() -> void:
	var game = load("res://scenes/game/main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	setup(game,8)
	var p = game.players[0]
	var q = game.players[1]
	p.relics = [2,6,7,12,13,14]
	p.state.return_battery_armed = true
	p.state.empty_casing_charge = true
	game.fire(0)
	var damage := 0.0
	for bullet in game.shots:
		if bullet.state.depth == 0:
			damage += bullet.damage
			q.hurt(bullet.damage,bullet.state.volley)
	assert(is_equal_approx(damage,5.6925) and q.state.hp > 2.0)
	assert(not p.state.return_battery_armed)
	print("PASS: full prism + core/cell/battery = %.4f damage (previously 8.4525)" % damage)
	# Measure representative non-prism damage through the actual collision/expiry paths.
	setup(game,2)
	game.fire(0)
	game.shots[0].state.pos = q.state.pos
	game.shots[0].state.life = 0.0
	game._physics_process(.001)
	assert(game.shots.size() == 8)
	for shard in game.shots:
		shard.state.pos = q.state.pos
		shard.step(.001,game.arena,q)
	assert(is_equal_approx(q.state.hp,7.35)) # separate fragments respect hit invulnerability
	setup(game,16)
	p.relics = [6,7,11,12]
	game.fire(0)
	var bank = game.shots[0]
	for bounce in range(2):
		bank.state.pos = Vector2(1087,100)
		bank.state.velocity = Vector2(370,0)
		bank.step(.02,game.arena,q)
	assert(is_equal_approx(bank.damage,2.028))
	setup(game,19)
	p.relics = [6,7]
	game.fire(0)
	game.shots[0].state.pos = q.state.pos
	game.shots[0].step(.001,game.arena,q)
	game._physics_process(.24)
	game.shots[-1].state.pos = q.state.pos
	game.shots[-1].step(.001,game.arena,q)
	assert(is_equal_approx(q.state.hp,6.482))
	setup(game,11)
	p.relics = [6,7]
	game.fire(0)
	game.shots[0].state.pos = q.state.pos
	game.shots[0].step(.001,game.arena,q)
	var well = game.spawn_well(q.state.pos,0)
	q.state.inv = 0.0
	well.step(.001,game.arena,game.players,game.shots)
	assert(is_equal_approx(q.state.hp,5.142)) # buffed seed 1.6 * core/cell + gravity .65
	var hp_before_dodge: float = q.state.hp
	q.handle_key(KEY_SHIFT,1,game.shots,p,game.arena)
	well.state.tick = 0.0
	well.step(.001,game.arena,game.players,game.shots)
	assert(q.state.hp == hp_before_dodge)
	assert(game.use_pulse(1) and game.wells.is_empty())
	print("PASS: clustered fragments .65, boosted 2-bounce 2.028, echo pair 1.518, mine + gravity tick 2.858")
	# Against each late-game weapon family, dodge prevents contact damage and melee
	# removes a dangerous projectile without spawning fragments or gravity wells.
	for weapon in [2,8,10,11,16,19]:
		setup(game,weapon)
		p.relics = [2,6,7,11,12,16]
		game.fire(0)
		var bullet = game.shots[0]
		q.handle_key(KEY_SHIFT,1,game.shots,p,game.arena)
		var hp: float = q.state.hp
		bullet.state.pos = q.state.pos
		bullet.step(.001,game.arena,q)
		assert(q.state.hp == hp)
		game.spawn_shot(0,weapon,0.0,{"pos":q.state.pos+Vector2(30,0),"speed":0.0})
		var target = game.shots[-1]
		q.state.roll = 0.0
		q.state.angle = 0.0
		q.try_melee(1,game.shots,p,game.arena)
		assert(target.state.dead and target.fragments().is_empty())
		game.spawn_well(q.state.pos,0)
		assert(game.use_pulse(1))
		assert(game.shots.is_empty() and game.wells.is_empty() and game.delayed_shots.is_empty())
	# CPU may steer during cooldown, but cannot rearm roll or nova until it expires.
	setup(game,1)
	q.state.pulses = 0
	q.relics = [5,12]
	q.state.dodge = .5
	q.state.ai_cd = -.1
	game.spawn_shot(0,0,0.0,{"pos":q.state.pos+Vector2(0,20),"speed":0.0})
	game.CpuAI.decide(game,q,p,.01)
	assert(q.state.roll == 0 and q.state.dodge == .5 and game.shots.size() == 1 and q.state.ai_cd == 0)
	q.state.dodge = 0.0
	game.CpuAI.decide(game,q,p,.01)
	assert(q.state.roll > 0 and game.shots.size() == 7)
	for bullet in game.shots.slice(1): assert(bullet.state.depth == 1)
	print("PASS: dodge/melee/pulse vs split/prism/gravity/mine/bounce/echo; CPU cooldown and derived nova")
	game.queue_free()
	quit()
