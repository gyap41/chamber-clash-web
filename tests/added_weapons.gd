extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func setup(game, id: int) -> void:
	game.new_match(301)
	preload("res://tests/helpers/battle.gd").start(game,id)
	game.supplies.reset()
	game.players[0].state.pos = Vector2(170,100)
	game.players[0].state.angle = 0.0
	game.players[1].state.pos = Vector2(950,500)
func run() -> void:
	var game = load("res://scenes/game/main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	var p = game.players[0]
	var q = game.players[1]
	for id in range(20,30):
		setup(game,id)
		var clip: int = p.weapon().clip
		game.fire(0)
		assert(p.weapon().clip == clip-1)
		assert(game.shots.size() == int(p.definition().get("count",1)))
		assert(is_equal_approx(game.shots[0].damage,float(p.definition().damage)))
		assert(game.shots[0].gun_id == id)
		game.hud.refresh(game.players,90,false,"",[0,0],"play")
	setup(game,22)
	game.fire(0)
	var b = game.shots[0]
	b.state.pos = Vector2(1087,100)
	b.step(.02,game.arena,q)
	assert(b.state.rebounds == 1 and b.state.bounce == 0 and b.state.life > 0)
	b.state.pos = Vector2(1087,100)
	b.state.velocity = Vector2(400,0)
	b.step(.02,game.arena,q)
	assert(b.state.life <= 0)
	setup(game,25)
	q.state.pos = Vector2(850,300)
	game.fire(0)
	b = game.shots[0]
	b.step(.1,game.arena,q)
	assert(is_equal_approx(b.state.velocity.angle(),.06))
	b.state.pos = Vector2(170,100)
	b.state.velocity = Vector2(340,0)
	q.state.pos = Vector2(100,300)
	b.step(.1,game.arena,q)
	assert(is_zero_approx(b.state.velocity.angle()))
	setup(game,27)
	game.fire(0)
	p.state.shot = 0.0
	game.fire(0)
	assert(is_equal_approx(game.shots[0].state.velocity.angle(),.04))
	assert(is_equal_approx(game.shots[1].state.velocity.angle(),-.04))
	setup(game,28)
	p.relics = [22,20,30]
	p.state.sight_time = 2.0
	p.weapon().clip = 1
	game.fire(0)
	assert(game.delayed_shots.size() == 2 and p.weapon().clip == 0)
	var volley: int = game.shots[0].state.volley
	assert(is_equal_approx(game.shots[0].damage,.65))
	assert(is_equal_approx(game.shots[0].speed,520*1.08*1.12))
	p.equip_slot(0)
	p.state.angle = PI
	game._physics_process(.081)
	assert(game.delayed_shots.size() == 1 and game.shots.size() == 2)
	game._physics_process(.08)
	assert(game.delayed_shots.is_empty() and game.shots.size() == 3)
	for shot in game.shots:
		assert(shot.gun_id == 28 and shot.state.volley == volley)
		assert(is_equal_approx(shot.damage,.65) and is_zero_approx(shot.state.velocity.angle()))
		assert(is_equal_approx(shot.speed,520*1.08*1.12))
	# Pulse clears enemy reservations, pause preserves them, round result discards them.
	setup(game,28)
	game.fire(0)
	game.paused = true
	game._physics_process(1.0)
	assert(game.delayed_shots.size() == 2)
	game.paused = false
	assert(game.use_pulse(1))
	assert(game.delayed_shots.is_empty() and game.shots.is_empty())
	p.state.shot = 0.0
	game.fire(0)
	game.remaining = 0.0
	game._physics_process(.001)
	assert(game.phase == "result" and game.delayed_shots.is_empty())
	setup(game,29)
	game.fire(0)
	for i in range(4):
		b = game.shots[i]
		assert(is_equal_approx(b.state.velocity.angle(),-.1 if i < 2 else .1))
		b.step(.249,game.arena,q)
		assert(not b.state.cross_turned)
		b.step(.002,game.arena,q)
		assert(b.state.cross_turned and is_equal_approx(b.state.velocity.angle(),.1 if i < 2 else -.1))
		b.step(.01,game.arena,q)
		assert(is_equal_approx(b.state.velocity.angle(),.1 if i < 2 else -.1))
	print("PASS: 10 weapons fire, one-bounce limit, homing cone, alternating aim, burst ammo/bonus/switch/pulse/pause/result, cross timing")
	game.queue_free()
	quit()
