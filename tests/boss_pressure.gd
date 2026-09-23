extends "res://tests/exploration_treasure_supplies.gd"

class BarrierArena:
	extends RefCounted
	var fighter_bounds := Rect2(0,0,800,700)
	var barrier := Rect2(300,0,80,330)
	func solid(point: Vector2, radius: float) -> bool:
		return not fighter_bounds.grow(-radius).has_point(point) or point.distance_to(point.clamp(barrier.position,barrier.end)) < radius
	func line_blocked(from: Vector2, to: Vector2) -> bool:
		for n in range(1,ceili(from.distance_to(to)/8)+1):
			if solid(from.move_toward(to,n*8),2): return true
		return false

func run() -> void:
	root.size = Vector2i(1120,800)
	var game = load("res://scenes/game/exploration.tscn").instantiate()
	game.random_floor = true
	root.add_child(game)
	game.set_physics_process(false)
	game.start_exploration(22)
	game.set_pause_reason("focus",false)
	var id: String = game.floor_data.rooms.keys().filter(func(key): return game.floor_data.rooms[key].role == "boss")[0]
	enter(game,id)
	game.BossFlow.finish_intro(game)
	assert(game.get_node("/root/Music").current_track == "boss")
	var boss = game.players[1]
	var player = game.players[0]
	assert(not player.rally_enabled)
	player.state.inv = 0
	player.hurt(1)
	player.recover_rally(10)
	assert(player.state.hp == 3 and player.rally_available() == 0 and player.rally_wounds.is_empty())
	player.state.hp = 4
	player.state.inv = 0
	boss.attack_phase = "chase"
	boss.attack_time = 0
	boss.state.pos = Vector2(1000,600)
	player.state.pos = Vector2(1400,600)
	boss.step(.01,1,player,game.arena)
	assert(boss.move_name == "dash" and boss.attack_phase == "windup")
	boss.step(1.01,1,player,game.arena)
	assert(boss.attack_phase == "dash")
	var start: Vector2 = boss.state.pos
	for frame in range(36): boss.step(.016,1,player,game.arena)
	assert(boss.state.pos.distance_to(start) > 250)
	assert(boss.attack_phase == "windup" and boss.move_name == "slam")
	assert(player.state.hp == 4) # The dash itself is not unavoidable contact damage.
	assert(boss.chain_left == 1 and not boss.combo_finisher)
	player.state.inv = 10
	boss.step(.31,1,player,game.arena)
	assert(boss.move_name == "dash" and boss.chain_left == 0)
	var locked_angle: float = boss.attack_angle
	player.state.pos += Vector2(0,50)
	boss.step(.66,1,player,game.arena)
	assert(boss.attack_phase == "dash" and boss.attack_angle == locked_angle)
	# The normal second strike ends the combo without a finishing wave.
	boss.attack_phase = "windup"
	boss.move_name = "slam"
	boss.attack_time = 0
	boss.step(.01,1,player,game.arena)
	assert(boss.attack_phase == "recover" and boss.waves.is_empty())
	# Sweep short segments into the boundary, even with a large timestep.
	boss.state.pos = Vector2(1800,600)
	assert(not game.arena.solid(boss.state.pos,44))
	boss.attack_phase = "dash"
	boss.dash_left = 620
	boss.attack_angle = 0
	boss.step(1.0,1,player,game.arena)
	assert(not game.arena.solid(boss.state.pos,44))
	boss.state.pos = Vector2(1000,600)
	player.state.pos = Vector2(1300,600)
	boss.attack_phase = "salvo"
	boss.move_name = "salvo"
	boss.attack_angle = 0
	boss.emissions_left = 2
	boss.emission_time = 0
	for frame in range(65): boss.step(.016,1,player,game.arena)
	assert(game.shots.size() == 24 and boss.attack_phase == "recover")
	for shot in game.shots:
		assert(is_equal_approx(shot.state.velocity.length(),280))
		assert(is_equal_approx(shot.damage,1))
	game.clear_field_objects()
	boss.attack_phase = "salvo"
	boss.emissions_left = 10
	boss.state.pos = Vector2(2000,900)
	player.state.pos = Vector2(100,100)
	boss.step(.016,1,player,game.arena)
	assert(game.shots.is_empty() and boss.emissions_left == 0)
	boss.state.pos = Vector2(1000,600)
	player.state.pos = Vector2(1100,600)
	player.state.hp = 4
	player.state.inv = 0
	boss.waves = [{"origin":Vector2(1000,600),"radius":0.0,"resolved":false,"previous":player.state.pos}]
	boss.step_waves(.25,player,game.arena)
	assert(player.state.hp == 3)
	player.state.inv = 0
	boss.step_waves(.01,player,game.arena)
	assert(player.state.hp == 3)
	boss.waves = [{"origin":Vector2(1000,600),"radius":0.0,"resolved":false,"previous":player.state.pos}]
	player.state.dodge = 0
	player.try_dodge()
	boss.step_waves(.25,player,game.arena)
	assert(player.state.hp == 3 and boss.waves[0].resolved)
	assert(boss.WAVE_INTERVAL > player.dodge_cooldown+.3)
	boss.waves.clear()
	boss.attack_phase = "shockwave"
	boss.move_name = "shockwave"
	boss.emissions_left = 3
	boss.emission_time = 0
	player.state.hp = 100
	player.state.pos = Vector2(1400,600)
	for frame in range(44): boss.step(.1,1,player,game.arena)
	assert(boss.emissions_left == 0 and boss.waves.size() == 3)
	game.set_pause_reason("menu",true)
	var frozen_spin: float = boss.spin_time
	var radius: float = boss.waves[0].radius
	game._physics_process(.2)
	assert(boss.waves[0].radius == radius and boss.spin_time == frozen_spin)
	game.set_pause_reason("menu",false)
	player.state.hp = 4
	boss.sync_visual()
	player.sync_visual()
	game.fit_field_camera()
	game.refresh_hud()
	await capture("boss-pressure-waves")
	# Every wave is emitted at landing, not while the body is airborne.
	boss.waves.clear()
	boss.attack_phase = "windup"
	boss.move_name = "shockwave"
	boss.attack_time = 0
	boss.step(.01,1,player,game.arena)
	assert(boss.emission_time == boss.JUMP_TIME and boss.waves.is_empty())
	boss.step(.3,1,player,game.arena)
	assert(boss.lift > 50 and boss.waves.is_empty())
	boss.sync_visual()
	await capture("spinner-jump")
	boss.step(.36,1,player,game.arena)
	assert(boss.lift == 0 and boss.waves.size() == 1)
	boss.emissions_left = 0
	boss.emission_time = boss.WAVE_INTERVAL
	boss.step(.41,1,player,game.arena)
	assert(boss.attack_phase == "recover" and not boss.waves.is_empty())
	boss.second_phase = false
	boss.state.hp = 24
	boss.step(.01,1,player,game.arena)
	boss.step(.65,1,player,game.arena)
	assert(boss.attack_phase == "transition" and boss.opening > 0 and boss.opening < 1)
	boss.sync_visual()
	await capture("spinner-opening")
	boss.step(.6,1,player,game.arena)
	assert(boss.opening == 1)
	# Enraged combo: each slam re-aims a new dash, then finally recovers.
	boss.second_phase = true
	boss.chain_left = 2
	boss.combo_finisher = true
	for strike in range(3):
		boss.state.pos = Vector2(1000,600)
		player.state.pos = Vector2(1120,600)
		player.state.inv = 10
		boss.attack_phase = "windup"
		boss.move_name = "slam"
		boss.attack_time = 0
		boss.step(.01,1,player,game.arena)
		if strike < 2:
			assert(boss.move_name == "dash" and boss.attack_phase == "windup")
			boss.step(.66,1,player,game.arena)
			assert(boss.attack_phase == "dash")
		else:
			assert(boss.attack_phase == "shockwave" and boss.emissions_left == 1)
			boss.waves.clear()
			boss.step(.4,1,player,game.arena)
			assert(boss.waves.is_empty() and boss.lift > 0)
			boss.step(.61,1,player,game.arena)
			assert(boss.waves.size() == 1 and boss.emissions_left == 0)
			boss.step(.41,1,player,game.arena)
			assert(boss.attack_phase == "recover")
	boss.second_phase = true
	for frame in range(80): boss.step_presentation(.016)
	assert(boss.opening == 1 and boss.particles.size() <= 48 and not boss.particles.is_empty())
	boss.sync_visual()
	player.state.hp = 4
	game.refresh_hud()
	await capture("spinner-enraged")
	game.clear_field_objects()
	boss.attack_phase = "windup"
	boss.move_name = "salvo"
	boss.attack_time = 0
	boss.step(.01,1,player,game.arena)
	assert(boss.emissions_left == 3)
	for frame in range(50): boss.step(.016,1,player,game.arena)
	assert(game.shots.size() == 48)
	for shot in game.shots:
		assert(is_equal_approx(shot.state.velocity.length(),330))
		assert(is_equal_approx(shot.damage,1))
	var saved_position: Vector2 = boss.state.pos
	var obstacle = BarrierArena.new()
	boss.state.pos = Vector2(150,160)
	boss.route.clear()
	boss.route_time = 0
	for frame in range(400):
		var axis: Vector2 = boss.chase_direction(.05,Vector2(550,160),obstacle)
		var next: Vector2 = boss.state.pos+axis*4
		assert(not obstacle.solid(next,44))
		boss.state.pos = next
		if boss.state.pos.distance_to(Vector2(550,160)) < 110: break
	assert(boss.state.pos.distance_to(Vector2(550,160)) < 110)
	boss.state.pos = saved_position
	boss.state.hp = 0
	game._physics_process(.01)
	assert(game.players.size() == 1 and game.exploration.status == "active")
	assert(game.get_node("/root/Music").current_track == "")
	game.queue_free()
	await process_frame
	print("PASS: distance-closing dash and wall sweep, staggered cannon salvos/offscreen cancel, wave hit/dodge/one-crossing/cadence/pause and cleanup")
	quit()
