extends "res://tests/exploration_treasure_supplies.gd"

func run() -> void:
	root.size = Vector2i(1120,800)
	var game = load("res://scenes/game/exploration.tscn").instantiate()
	game.random_floor = true
	root.add_child(game)
	game.set_physics_process(false)
	game.start_exploration(22)
	game.set_pause_reason("focus",false)
	var room: String = game.floor_data.rooms.keys().filter(func(id): return game.floor_data.rooms[id].role == "boss")[0]
	enter(game,room)
	var boss = game.players[1]
	var player = game.players[0]
	boss.state.pos = Vector2(1000,600)
	player.state.pos = Vector2(1240,660)
	boss.attack_phase = "recover"
	boss.attack_time = 10
	game._physics_process(.01)
	assert(game.sound.boss_engine.playing)
	game.set_pause_reason("menu",true)
	assert(game.sound.boss_engine.stream_paused)
	game.set_pause_reason("menu",false)
	assert(not game.sound.boss_engine.stream_paused)
	game.sound.set_enabled(false)
	assert(not game.sound.boss_engine.playing)
	game.sound.set_enabled(true)
	var events: Array = []
	game.sound.played.connect(func(kind, _id): events.append(kind))
	# The actual bullet and the flash share an exact world-space origin in all directions.
	for angle in [0.0,PI/2,PI,-PI/2]:
		game.clear_field_objects()
		boss.fire_cannon(1,game.arena,angle,true)
		assert(game.shots.size() == 1)
		assert(game.shots[0].state.pos.is_equal_approx(boss.state.pos+boss.enemy_visual_snapshot().muzzle))
		assert(is_equal_approx(boss.recoil,1.8))
	boss.state.hp = 24
	boss.step(.01,1,player,game.arena)
	assert(events.count("boss_overdrive") == 1)
	for angle in [0.0,PI/2,PI,-PI/2]:
		boss.attack_angle = angle
		boss.state.angle = angle
		boss.attack_time = .55
		boss.step_presentation(.01)
		boss.sync_visual()
		player.sync_visual()
		game.fit_field_camera()
		await capture("boss-opening-"+str(int(rad_to_deg(angle))))
	boss.attack_phase = "recover"
	boss.begin_recovery()
	assert(events.count("boss_vent") == 1)
	boss.state.inv = 0
	boss.hurt(100)
	assert(events.count("boss_internal") == 1)
	game._physics_process(.01)
	assert(game.phase == "play" and game.players.size() == 1)
	assert(not game.hud.get_node("Root/Outcome").visible)
	assert(game.sound.voices.any(func(voice): return voice.get_meta("kind","") == "boss_internal" and voice.stream != null))
	assert(not game.sound.boss_engine.playing)
	assert(events.count("win") == 0)
	var remains = get_nodes_in_group("enemy_death_visuals")[0]
	game.set_pause_reason("focus",true)
	var frozen: float = remains.elapsed
	game._physics_process(.5)
	assert(remains.elapsed == frozen and events.count("boss_explosion") == 0)
	game.set_pause_reason("focus",false)
	game._physics_process(.24)
	assert(events.count("boss_internal") == 2)
	game._physics_process(1.2)
	assert(events.count("boss_explosion") == 1)
	game._physics_process(.2)
	await capture("boss-destruction")
	for frame in range(185): game._physics_process(.02)
	await process_frame
	assert(events.count("boss_explosion") == 1 and events.count("win") == 0)
	assert(not game.hud.get_node("Root/Outcome").visible)
	assert(game.Reward.current(game).state == "closed")
	assert(get_nodes_in_group("enemy_death_visuals").is_empty())
	game.start_exploration(22)
	assert(not game.sound.boss_engine.playing)
	game.queue_free()
	await process_frame
	print("PASS: boss muzzle registration, recoil, transition/vent cues, engine pause/mute, death audio after retirement, reward after explosion and retry cleanup")
	quit()
