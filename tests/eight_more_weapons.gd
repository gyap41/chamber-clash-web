extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var game = load("res://scenes/game/main.tscn").instantiate()
	root.add_child(game)
	preload("res://tests/helpers/battle.gd").passive_opponents(game)
	game.set_physics_process(false)
	var p = game.players[0]
	var q = game.players[1]
	var seen := {}
	for id in range(30,38):
		game.new_match(id)
		var m = game.match_state
		m.gold[0] = 20
		m._set_products(0,[m.gun_token(id)])
		assert(m.claim(0,m.gun_token(id)))
		preload("res://tests/helpers/preparation.gd").rectangle(m)
		assert(m.place(0,m.gun_token(id),Vector2i.ZERO))
		assert(m.sale_value(0,m.gun_token(id)) > 0)
		preload("res://tests/helpers/battle.gd").start(game,id)
		game.supplies.reset()
		p.state.pos = Vector2(170,100)
		p.state.angle = 0.0
		q.state.pos = Vector2(950,500)
		var clip: int = p.weapon().clip
		game.fire(0)
		assert(p.weapon().clip == clip-1)
		assert(game.shots.size() == int(p.definition().get("count",1)))
		assert(is_equal_approx(game.shots[0].damage,p.definition().damage))
		var b = game.shots[0]
		match id:
			30: assert(is_equal_approx(b.speed,680) and is_equal_approx(b.damage,1.4))
			31: assert(is_equal_approx(game.shots[0].state.velocity.angle(),-.33) and game.shots.size() == 4)
			32:
				for bounce in range(3):
					b.state.pos = Vector2(1087,100)
					b.state.velocity = Vector2(360,0)
					b.step(.02,game.arena,q)
					assert(b.state.rebounds == bounce+1 and b.state.life > 0)
				b.state.pos = Vector2(1087,100)
				b.state.velocity = Vector2(360,0)
				b.step(.02,game.arena,q)
				assert(b.state.life <= 0)
			33: assert(game.shots.size() == 2 and game.shots.all(func(shot): return shot.state.boomerang))
			34:
				b.step(.1,game.arena,q)
				assert(is_equal_approx(b.state.velocity.length(),200))
			35:
				assert(is_equal_approx(b.state.life,3.6))
				b.step(.61,game.arena,q)
				assert(b.state.velocity == Vector2.ZERO)
				q.state.pos = b.state.pos+Vector2(70,0)
				b.step(.01,game.arena,q)
				assert(b.state.launched and is_equal_approx(b.state.velocity.length(),400))
			36:
				assert(game.delayed_shots.size() == 1)
				p.equip_slot(0)
				game._physics_process(.241)
				assert(game.shots.size() == 2 and game.shots[-1].gun_id == 36 and is_equal_approx(game.shots[-1].damage,1.15))
			37:
				assert(game.shots.size() == 7 and b.state.bounce == 1)
				b.state.pos = Vector2(170,100)
				b.state.velocity = Vector2(400,0)
				q.state.pos = Vector2(850,300)
				b.step(.1,game.arena,q)
				assert(is_equal_approx(b.state.velocity.angle(),.09))
		assert(id in game.Weapons.rarity_pool(p.resolved_definition(id).rarity))
		for n in range(100):
			var picked: int = game.supplies.weighted_gun()
			assert(game.Weapons.distributable(picked))
			seen[picked] = true
	assert(range(30,37).all(func(id): return seen.has(id)))
	print("PASS: eight additional weapon purchase/shape/shot profiles, triple bounce, dual return, acceleration, trap tuning, delayed rail, fan cone and field pools")
	game.queue_free()
	quit()
