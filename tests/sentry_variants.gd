extends "res://tests/fire_pouch_lizard.gd"
func run() -> void:
	root.size = Vector2i(1120,800)
	var game = load("res://scenes/game/exploration.tscn").instantiate()
	game.random_floor = true
	root.add_child(game)
	game.set_physics_process(false)
	game.start_exploration(22)
	game.set_pause_reason("focus",false)
	var id: String = game.floor_data.rooms.keys().filter(func(key): return game.floor_data.rooms[key].role == "normal")[0]
	game.Encounter.retire(game)
	game.exploration.enter_room(id,game.room_data(id).field.field_id)
	assert(game.arena.configure_field(field(),1).is_empty())
	game.players[0].state.pos = Vector2(700,450)
	game.exploration.room_state(id).enemy_ids = ["ram_sentry","ring_sentry","runner_sentry"]
	game.Encounter.begin(game)
	assert(game.players.size() == 4)
	var ram = game.players[1]
	var ring = game.players[2]
	var runner = game.players[3]
	assert(ram.spec.id == "ram_sentry" and ring.spec.id == "ring_sentry" and runner.spec.id == "runner_sentry")
	var player = game.players[0]
	reset_pair(game,ram)
	ram.step(1.81,1,player,game.arena)
	assert(ram.attack_phase == "windup")
	ram.step(1.16,1,player,game.arena)
	assert(ram.attack_phase == "dash" and game.shots.is_empty())
	player.state.pos.y += 100
	ram.step(1,1,player,game.arena)
	assert(ram.attack_phase == "recover" and player.state.hp == 8)
	assert(is_equal_approx(ram.state.pos.y,450))
	# A large step must not tunnel through the wall, or damage through it.
	reset_pair(game,ram)
	assert(game.arena.configure_field(field(true),1).is_empty())
	ram.attack_angle = 0
	ram.spit(1,game.arena)
	ram.step(2,1,player,game.arena)
	assert(ram.state.pos.x < 600 and ram.attack_phase == "recover" and player.state.hp == 8)
	reset_pair(game,ram)
	ram.attack_angle = 0
	ram.spit(1,game.arena)
	ram.step(1,1,player,game.arena)
	assert(is_equal_approx(player.state.hp,6.7) and ram.attack_phase == "recover")
	ram.step(.1,1,player,game.arena)
	assert(is_equal_approx(player.state.hp,6.7))
	reset_pair(game,ring)
	ring.step(2.01,2,player,game.arena)
	assert(ring.attack_phase == "windup")
	ring.step(1.31,2,player,game.arena)
	assert(game.shots.size() == 11)
	ring.step(.66,2,player,game.arena)
	assert(game.shots.size() == 22)
	for shot in game.shots:
		assert(absf(angle_difference(0,shot.state.velocity.angle())) >= PI/4)
	ring.step(.66,2,player,game.arena)
	assert(ring.attack_phase == "recover")
	assert(game.combat.use_pulse(0) and game.shots.is_empty())
	reset_pair(game,ring)
	ring.step(2.01,2,player,game.arena)
	player.state.pos = Vector2(1500,900)
	ring.step(1.4,2,player,game.arena)
	assert(game.shots.is_empty() and ring.attack_phase == "recover")
	reset_pair(game,runner)
	player.state.pos = Vector2(540,450)
	runner.step(1.31,3,player,game.arena)
	assert(runner.attack_phase == "windup")
	runner.step(.56,3,player,game.arena)
	assert(is_equal_approx(player.state.hp,7.3))
	for actor in [ram,ring,runner]:
		actor.state.inv = 0
		actor.hurt(100)
		var before: Vector2 = actor.state.pos
		actor.step(3,game.players.find(actor),player,game.arena)
		assert(actor.state.pos == before and game.shots.is_empty())
		assert(not get_nodes_in_group("enemy_death_visuals")[-1].organic)
	# Composition limits, intro protection, and reachable local open space.
	for count in range(8):
		var ids: Array = game.Encounter.composition(game.arena,count > 0,count)
		assert(ids.count("ram_sentry")+ids.count("ring_sentry") <= 1)
		if count == 0: assert(ids == ["workshop_sentry","workshop_sentry","workshop_sentry"])
		if count in [3,5]: assert(ids.size() == 3)
	# Representative normal-size view; no new geometry or generated art.
	game.clear_field_objects()
	game.clear_enemy_deaths()
	player.state.hp = 4
	for pair in [[ram,Vector2(690,450)],[ring,Vector2(830,450)],[runner,Vector2(550,450)]]:
		pair[0].prepare(pair[1])
		pair[0].attack_phase = "windup"
		pair[0].attack_time = .2
		pair[0].attack_angle = 0
		pair[0].sync_visual()
	player.state.pos = Vector2(960,450)
	player.sync_visual()
	game.fit_field_camera()
	game.refresh_hud()
	await capture("sentry-variants")
	game.Encounter.retire(game)
	assert(game.players.size() == 1 and game.shots.is_empty())
	var observed := {}
	for seed_value in range(12):
		game.start_exploration(seed_value)
		for room_id in game.floor_data.rooms:
			if game.floor_data.rooms[room_id].role != "normal": continue
			game.Encounter.retire(game)
			game.exploration.enter_room(room_id,game.room_data(room_id).field.field_id)
			game.switch_field(game.room_data(room_id).field)
			game.Encounter.begin(game)
			var elites := 0
			for actor in game.players.slice(1):
				observed[actor.spec.id] = true
				if actor.spec.id in ["ram_sentry","ring_sentry"]:
					elites += 1
					for n in range(8): assert(Navigation.segment_clear(game.arena,actor.state.pos,actor.state.pos+Vector2.from_angle(n*TAU/8)*96,20))
			assert(elites <= 1)
	assert(observed.has("runner_sentry") and observed.has("ram_sentry") and observed.has("ring_sentry"))
	game.queue_free()
	await process_frame
	print("PASS: three sentry variants, charge miss/hit/wall recovery, ring escape sector, death, pulse, intro and elite limits")
	quit()
