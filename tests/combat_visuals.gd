extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var game = load("res://scenes/game/main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	preload("res://tests/helpers/battle.gd").start(game,1)
	var fx = game.combat_visuals
	var p = game.players[0]
	var q = game.players[1]
	assert(p.hurt(1))
	assert(fx.particles.size() == 14)
	assert(not p.hurt(1) and fx.particles.size() == 14)
	fx.clear()
	p.handle_key(KEY_SPACE,0,game.shots,q,game.arena)
	assert(fx.particles.size() == 8)
	p.handle_key(KEY_SPACE,0,game.shots,q,game.arena)
	assert(fx.particles.size() == 8)
	p.state.roll = 0.0
	fx.clear()
	# Each real reflection/impact emits the corresponding atlas row.
	game.spawn_shot(0,16,0,{"pos":Vector2(1087,100)})
	game.shots.back().step(.02,game.arena,q)
	assert(fx.weapon_effects.size() == 1 and fx.weapon_effects[0].row == 0)
	assert(fx.particles.size() == 4)
	fx.clear()
	game.spawn_shot(0,18,0,{"pos":Vector2(1087,100)})
	game.shots.back().step(.02,game.arena,q)
	assert(fx.weapon_effects.size() == 1 and fx.weapon_effects[0].row == 2)
	fx.clear()
	game.spawn_shot(0,17,0,{"parcel":true,"life":.001})
	game._physics_process(.01)
	assert(fx.weapon_effects.any(func(e): return e.row == 1))
	fx.clear()
	# Explicit removal must not play the parcel explosion.
	game.spawn_shot(0,17,0,{"parcel":true})
	game.shots.back().state.dead = true
	game._physics_process(.01)
	assert(not fx.weapon_effects.any(func(e): return e.row == 1))
	game.reset_round()
	game.phase = "play"
	p.add_gun(19)
	p.state.shot = 0.0
	game.fire(0)
	assert(fx.particles.size() == 4 and fx.weapon_effects.is_empty())
	game._physics_process(.25)
	assert(fx.weapon_effects.any(func(e): return e.row == 3))
	game.paused = true
	var age: float = fx.weapon_effects.back().age
	game._physics_process(.1)
	assert(fx.weapon_effects.back().age == age)
	game.paused = false
	game.result = "DRAW"
	game.phase = "result"
	game._physics_process(.1)
	assert(fx.weapon_effects.back().age == age)
	game.reset_round()
	assert(fx.weapon_effects.is_empty() and fx.particles.is_empty())
	# Bounded lifetime and memory, including simultaneous bursts.
	fx.burst(Vector2.ZERO,Color.WHITE,700)
	assert(fx.particles.size() == 650)
	for i in range(45): fx.weapon_effect(i%4,Vector2.ZERO)
	assert(fx.weapon_effects.size() == 40)
	fx.step(1.0)
	assert(fx.weapon_effects.is_empty() and fx.particles.is_empty())
	print("PASS: damage/dodge/muzzle and weapon reflection/impact/parcel/echo events, removal suppression, pause/result/reset, effect caps and expiry")
	game.queue_free()
	quit()
