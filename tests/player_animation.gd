extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var game = load("res://scenes/game/main.tscn").instantiate()
	root.add_child(game)
	preload("res://tests/helpers/battle.gd").passive_opponents(game)
	game.set_physics_process(false)
	game.phase = "play"
	var p = game.players[0]
	var q = game.players[1]
	var anim = p.get_node("Animation")
	var sprite = p.get_node("Sprite")
	var original: Transform2D = sprite.transform
	p.add_relic(0)
	p.add_relic(3)
	p.add_relic(4)
	p.sync_visual()
	assert(anim.orbit_positions.size() == 3)
	assert(anim.orbit_positions[0].is_equal_approx(Vector2(32,10)))
	var old_orbit: Vector2 = anim.orbit_positions[0]
	p.step(.05,0,q,game.arena,false,{"dx":1.0,"dy":0.0,"shoot":false,"aim_jitter":0.0})
	assert(anim.walk > 0 and anim.leg_step != 0)
	assert(anim.orbit_positions[0] != old_orbit and sprite.transform == original)
	assert(not sprite.visible)
	p.step(.01,0,q,game.arena,false,{"dx":0.0,"dy":0.0,"shoot":false,"aim_jitter":0.0})
	assert(anim.leg_step == 0)
	p.handle_key(KEY_SPACE,0,game.shots,q,game.arena)
	p.step(.065,0,q,game.arena,false,{"dx":0.0,"dy":0.0,"shoot":false,"aim_jitter":0.0})
	assert(is_equal_approx(anim.pose.get_rotation(),PI/2))
	assert(is_equal_approx(anim.pose.get_scale().y,.8))
	assert(sprite.transform == original and p.position == p.state.pos)
	game.paused = true
	var time: float = anim.elapsed
	var pose: Transform2D = anim.pose
	game._physics_process(.1)
	assert(anim.elapsed == time and anim.pose == pose)
	game.paused = false
	game.result = "DRAW"
	game._physics_process(.1)
	assert(anim.elapsed == time)
	game.reset_round()
	assert(anim.orbit_positions.is_empty() and anim.walk == 0 and anim.recoil == 0)
	assert(p.get_node("Weapon").modulate.a == 1.0)
	assert(p.add_gun(0)) # Reset no longer grants an automatic sidearm.
	game.phase = "play"
	p.state.shot = 0
	game.fire(0)
	assert(anim.recoil == 1 and is_equal_approx(anim.muzzle,.075))
	p.step(.05,0,q,game.arena)
	assert(is_equal_approx(anim.recoil,.55) and is_equal_approx(anim.muzzle,.025))
	p.state.inv = 1.0
	anim.elapsed = .05
	p.sync_visual()
	assert(is_equal_approx(p.get_node("Weapon").modulate.a,.55))
	game.reset_round()
	assert(anim.muzzle == 0 and anim.recoil == 0 and anim.orbit_positions.is_empty())
	print("PASS: orbit count/motion/reset, walking/idle, roll shared pose, source transform/physics preservation, pause/result, recoil/muzzle/invulnerability")
	game.queue_free()
	quit()
