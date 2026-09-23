extends "res://tests/exploration_treasure_supplies.gd"
var attacks := 0
func run() -> void:
	var game = load("res://scenes/game/exploration.tscn").instantiate()
	game.random_floor = true
	root.add_child(game)
	game.set_physics_process(false)
	game.start_exploration(22)
	game.set_pause_reason("focus",false)
	var id: String = game.floor_data.rooms.keys().filter(func(key): return game.floor_data.rooms[key].role == "boss")[0]
	enter(game,id)
	var boss = game.players[1]
	var player = game.players[0]
	boss.sound_requested.connect(func(kind,_id):
		if kind in ["rapid","boss_salvo","boss_cannon","boss_impact","boss_dash"]: attacks += 1)
	# Reproduced: boss cannot enter the player's narrow southern wall margin.
	var cases := [[Vector2(1080,1080),Vector2(890,1080)], [Vector2(1160,1080),Vector2(1350,1080)]]
	var failures := 0
	for pair in cases:
		boss.prepare(pair[0])
		boss.attack_phase = "chase"
		boss.attack_time = 0
		boss.move_index = 4
		player.state.pos = pair[1]
		player.state.hp = 4
		attacks = 0
		for frame in range(180):
			player.state.inv = 100
			if frame%15 == 0: boss.hurt(.05,-1,false,{},player)
			boss.step(.016,1,player,game.arena)
			if attacks > 0: break
		if attacks == 0:
			failures += 1
			print("INACTIVE base=",pair[0]," target=",player.state.pos," end=",boss.state.pos," phase=",boss.attack_phase," move=",boss.move_name)
		game.clear_field_objects()
		if failures >= 3: break
	assert(failures == 0)
	print("PASS: wall-margin melee deadlock recovers to a ranged attack")
	# The foot can leave the conservative start area while the body is on screen.
	boss.prepare(Vector2(1100,890))
	player.state.pos = Vector2(1100,600)
	player.state.inv = 100
	assert(not boss.visible_to_target(game.arena,player.state.pos))
	assert(boss.attack_visible(game.arena,player.state.pos))
	boss.attack_phase = "salvo"
	boss.emissions_left = 2
	boss.emission_time = 0
	boss.step(.016,1,player,game.arena)
	assert(boss.attack_phase == "salvo" and boss.emissions_left == 1)
	player.state.pos = Vector2(200,200)
	boss.step(.016,1,player,game.arena)
	assert(boss.attack_phase == "chase" and boss.attack_time == 0)
	boss.state.pos = Vector2(1100,600)
	player.state.pos = Vector2(1500,600)
	boss.attack_phase = "dash"
	boss.dash_left = 0
	boss.step(.016,1,player,game.arena)
	assert(boss.attack_phase == "chase")
	# Sub-pixel remainder cannot advance a float32 position at room coordinates.
	# Previously this left the boss in dash forever until the player approached.
	for remainder in [.00001,.0001,.1,.49]:
		boss.prepare(Vector2(1100,600))
		player.state.pos = Vector2(1500,600)
		player.state.hp = 4
		player.state.inv = 100
		boss.attack_phase = "dash"
		boss.attack_angle = 0
		boss.dash_left = remainder
		boss.step(.016,1,player,game.arena)
		assert(boss.attack_phase == "chase")
		attacks = 0
		for frame in range(200): boss.step(.016,1,player,game.arena)
		assert(attacks > 0) # No player approach is needed to restart attacks.
		game.clear_field_objects()
	print("PASS: tiny dash remainder exits and resumes attack without player approach")
	game.queue_free()
	await process_frame
	quit()
