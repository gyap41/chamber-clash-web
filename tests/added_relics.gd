extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func setup(game, id: int = 0) -> void:
	game.new_match(302)
	preload("res://tests/helpers/battle.gd").start(game,id)
	game.supplies.reset()
	game.players[0].state.pos = Vector2(170,100)
	game.players[0].state.angle = 0.0
	game.players[0].relic_capacity = 24
	game.players[1].state.pos = Vector2(950,500)
func run() -> void:
	var game = load("res://scenes/game/main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	var p = game.players[0]
	var q = game.players[1]
	setup(game)
	assert(p.add_relic(20))
	game.fire(0)
	assert(is_equal_approx(game.shots[0].speed,480*1.15))
	game.spawn_shot(0,0,0,{"depth":1,"speed":200.0})
	assert(is_equal_approx(game.shots[-1].speed,200.0))
	# Magazine acquisition changes capacity only; all reload/top-up paths use it.
	assert(p.add_relic(21))
	assert(p.weapon().clip == 15 and p.definition().mag == 18 and game.Weapons.definition(0).mag == 16)
	p.weapon().clip = 17
	var reserve: int = p.weapon().reserve
	p.start_reload()
	p.finish_reload()
	assert(p.weapon().clip == 18 and p.weapon().reserve == reserve-1)
	assert(p.add_gun(28) and p.weapon().clip == 10)
	p.relics.append(8)
	p.inventory[0].clip = 17
	p.equip_slot(0)
	p.equip_slot(1)
	assert(p.inventory[0].clip == 18)
	p.apply_build({"owned":["gun:0",21],"equipped":["gun:0",21],"positions":{"gun:0":Vector2i.ZERO,21:Vector2i(2,0)}},8,true)
	assert(p.weapon().clip == 18 and p.weapon().reserve == 64)
	setup(game,24)
	p.relics = [22]
	p.weapon().clip = 1
	game.fire(0)
	assert(is_equal_approx(game.shots[0].damage,.55) and is_equal_approx(game.shots[1].damage,.55))
	setup(game,19)
	p.relics = [22]
	p.weapon().clip = 1
	game.fire(0)
	assert(is_equal_approx(game.shots[0].damage,.85) and is_equal_approx(game.delayed_shots[0].damage,.55))
	setup(game)
	p.relics = [23]
	p.state.dodge = 1.0
	p.weapon().clip = 11
	p.start_reload()
	p.finish_reload()
	assert(is_equal_approx(p.state.dodge,.75) and p.state.cool_grip_cd == 2.0)
	p.state.reload = 0.0
	p.weapon().clip = 11
	p.start_reload()
	p.finish_reload()
	assert(is_equal_approx(p.state.dodge,.75))
	setup(game)
	p.relics = [24,25,26]
	p.handle_key(KEY_SPACE,0,game.shots,q,game.arena)
	assert(is_equal_approx(p.state.dodge,1.65*.9))
	assert(is_equal_approx(p.state.roll,.26) and is_equal_approx(p.state.inv,.31))
	p.step(.26,0,q,game.arena)
	assert(is_equal_approx(p.effective_move_speed(),205*1.1))
	p.step(.81,0,q,game.arena)
	assert(is_equal_approx(p.effective_move_speed(),205))
	p.state.angle = 0.0
	p.try_melee(0,game.shots,q,game.arena)
	assert(is_equal_approx(p.state.melee,1.1*.85) and is_equal_approx(p.state.slash,.16))
	# Successful parry charges once; hazard, dodge and bell do not consume the shell.
	setup(game)
	p.relics = [27]
	game.spawn_shot(1,0,0,{"pos":p.state.pos+Vector2(40,0)})
	p.try_melee(0,game.shots,q,game.arena)
	assert(p.state.shell_time == 2.0 and p.state.shell_cd == 6.0)
	assert(p.hurt(.2,-1,true) and p.state.shell_time == 2.0)
	p.state.inv = 0.0
	p.state.roll = .1
	assert(not p.hurt(1,301) and p.state.shell_time == 2.0)
	p.state.roll = 0.0
	p.relics.append(3)
	assert(not p.hurt(1,302) and p.state.shell_time == 2.0)
	p.state.inv = 0.0
	var hp: float = p.state.hp
	assert(p.hurt(1,303) and is_equal_approx(p.state.hp,hp-.5) and p.state.shell_time == 0)
	assert(p.hurt(1,303) and is_equal_approx(p.state.hp,hp-1.5))
	# A fully absorbed hit does not arm healing, or block the rest of a volley.
	p.state.inv = 0.0
	p.state.shell_time = 2.0
	p.relics = [27,28]
	assert(not p.hurt(.4,304) and p.state.aid_used == 0)
	assert(p.hurt(.4,304) and p.state.aid_used == 1)
	setup(game)
	p.relics = [28]
	for cycle in range(3):
		p.state.inv = 0.0
		hp = p.state.hp
		assert(p.hurt(1,400+cycle))
		assert(p.state.aid_used == mini(cycle+1,2))
		p.step(2.01,0,q,game.arena)
		assert(is_equal_approx(p.state.hp,hp-(.5 if cycle < 2 else 1.0)))
	setup(game)
	p.relics = [28]
	assert(p.hurt(.5,-1,true) and p.state.aid_time == 0)
	p.state.inv = 0.0
	assert(p.hurt(1,500))
	p.state.inv = 0.0
	assert(p.hurt(1,501) and p.state.aid_used == 1) # pending heals never stack
	p.state.inv = 0.0
	assert(p.hurt(20,502))
	p.step(2.1,0,q,game.arena)
	assert(p.state.hp == 0)
	setup(game,28)
	p.relics = [29,30]
	assert(game.use_pulse(0) and p.state.boots_time == 2.0)
	assert(is_equal_approx(p.effective_move_speed(),205*1.15))
	p.equip_slot(0)
	assert(p.state.sight_time == 2.0)
	p.state.shot = 0.0
	game.fire(0)
	assert(is_equal_approx(game.shots[-1].speed,480*1.25) and p.state.sight_time == 0)
	p.equip_slot(1)
	assert(p.state.sight_time == 0) # cannot refresh during cooldown
	p.step(2.01,0,q,game.arena)
	assert(is_equal_approx(p.effective_move_speed(),205))
	setup(game,1)
	p.relics = [31]
	game.fire(0)
	var b = game.shots[0]
	for bounce in range(2):
		b.state.pos = Vector2(1087,100)
		b.state.velocity = Vector2(390,0)
		b.step(.02,game.arena,q)
		assert(is_equal_approx(b.damage,1.1))
	game.spawn_shot(0,1,0,{"depth":1})
	b = game.shots[-1]
	b.state.pos = Vector2(1087,100)
	b.step(.02,game.arena,q)
	assert(is_equal_approx(b.damage,1.0))
	for id in [2,14,17,9]:
		setup(game,id)
		p.relics = [32]
		p.weapon().clip = 1
		game.fire(0)
		b = game.shots[0]
		var expected: float = .45 if id == 9 else (.35 if id == 17 else .65)*1.1
		assert(is_equal_approx(b.fragments().damage,expected))
		b.state.dead = true
		assert(b.fragments().is_empty())
	setup(game,5)
	p.relics = [33,21]
	p.weapon().clip = 6
	reserve = p.weapon().reserve
	game.fire(0)
	b = game.shots[0]
	p.equip_slot(0)
	b.state.age = .66
	b.state.pos = p.state.pos+Vector2(10,0)
	b.step(.01,game.arena,q)
	assert(p.inventory[1].clip == 6 and p.inventory[1].reserve == reserve-1 and p.state.reel_cd == 1.0)
	p.recover_projectile(5)
	assert(p.inventory[1].clip == 6)
	setup(game)
	p.relics = [34]
	var chest = game.supplies.put_item("weapon",28,p.state.pos)
	chest.age = .6
	game.supplies.interact(0)
	game.supplies.step(1.19)
	assert(not chest.used and not p.owns(28))
	assert("1.2秒" in chest.get_node("Hint").text)
	game.supplies.step(.011)
	assert(not p.owns(28) and "gun:28" in game.match_state.reserve_items(0))
	assert(is_equal_approx(q.effective_chest_duration(1.5),1.5))
	p.reset(Vector2(170,100))
	assert(p.state.aid_used == 0)
	for timer in p.ITEM_TIMERS: assert(p.state[timer] == 0)
	print("PASS: 15 relic effects, caps, derived exclusions, effective magazines, defense priority, heal limit/death, recovery source, chest/UI duration and round reset")
	game.queue_free()
	quit()
