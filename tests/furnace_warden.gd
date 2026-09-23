extends "res://tests/exploration_treasure_supplies.gd"

func run() -> void:
	root.size = Vector2i(1120,800)
	var game = load("res://scenes/game/exploration.tscn").instantiate()
	game.random_floor = true
	root.add_child(game)
	game.set_physics_process(false)
	game.start_exploration(22)
	game.set_pause_reason("focus",false)
	var room_id: String = game.floor_data.rooms.keys().filter(func(id): return game.floor_data.rooms[id].role == "boss")[0]
	enter(game,room_id)
	var boss = game.players[1]
	var player = game.players[0]
	assert(boss.spec.id == "furnace_warden" and boss.state.hp == 48 and boss.radius == 44)
	assert(not game.arena.solid(boss.state.pos,boss.radius))
	assert(not game.try_enter_door() and not boss.hurt(10))
	game.apply_command(0,{"pulse":true})
	assert(player.state.pulses == 3)
	var timer: float = boss.attack_time
	game.set_pause_reason("menu",true)
	game._physics_process(.5)
	assert(boss.attack_time == timer)
	game.set_pause_reason("menu",false)
	game._physics_process(2.5)
	assert(not game.boss_intro())
	player.state.pos = boss.state.pos+Vector2(0,125)
	player.sync_visual()
	game.fit_field_camera()
	boss.attack_phase = "chase"
	boss.attack_time = 0
	boss.step(.01,1,player,game.arena)
	assert(boss.attack_phase == "windup" and boss.move_name == "slam")
	boss.sync_visual()
	game.refresh_hud()
	await capture("boss-slam")
	var hp: float = player.state.hp
	boss.step(1.01,1,player,game.arena)
	assert(is_equal_approx(player.state.hp,hp-1.5))
	player.state.hp = 4
	player.state.inv = 0
	boss.move_name = "slam"
	boss.attack_angle = PI/2
	player.state.pos = boss.state.pos+Vector2(140,0)
	boss.execute_attack(1,player,game.arena)
	assert(player.state.hp == 4)
	boss.move_name = "salvo"
	boss.fire_salvo(1,game.arena)
	assert(game.shots.size() == 12)
	assert(game.combat.use_pulse(0) and game.shots.is_empty())
	player.state.inv = 0
	boss.move_name = "heat"
	boss.execute_attack(1,player,game.arena)
	assert(player.state.hp == 3)
	player.state.pos = boss.state.pos+Vector2(250,0)
	player.state.inv = 0
	boss.execute_attack(1,player,game.arena)
	assert(player.state.hp == 3)
	boss.attack_phase = "windup"
	boss.attack_time = .1
	player.state.pos = Vector2(100,100)
	boss.step(.2,1,player,game.arena)
	assert(boss.attack_phase == "chase" and boss.attack_time == 0 and game.shots.is_empty())
	player.state.pos = boss.state.pos+Vector2(140,0)
	boss.state.inv = 0
	boss.state.hp = 24
	boss.step(.01,1,player,game.arena)
	assert(boss.second_phase and boss.attack_phase == "transition")
	boss.step(1.21,1,player,game.arena)
	assert(boss.move_name == "shockwave")
	boss.state.inv = 0
	boss.hurt(100)
	game._physics_process(.01)
	assert(game.exploration.status == "active" and game.phase == "play")
	assert(game.players.size() == 1 and game.shots.is_empty() and game.wells.is_empty())
	assert(game.Reward.current(game).source == "boss")
	await capture("boss-clear")
	for frame in range(240): game._physics_process(.02)
	await process_frame
	assert(get_nodes_in_group("enemy_death_visuals").is_empty())
	game.start_exploration(22)
	enter(game,room_id)
	boss = game.players[1]
	boss.attack_phase = "recover"
	boss.state.hp = 0
	game.players[0].state.hp = 0
	game._physics_process(.01)
	assert(game.exploration.status == "dead")
	game.queue_free()
	await process_frame
	print("PASS: boss intro/pause/lock, slam dodge and damage, salvo/pulse, heat, phase transition, boss reward cleanup, retry and death priority")
	quit()
