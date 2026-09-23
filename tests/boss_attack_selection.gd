extends "res://tests/exploration_treasure_supplies.gd"

func run() -> void:
	var game = load("res://scenes/game/exploration.tscn").instantiate()
	game.random_floor = true
	root.add_child(game)
	game.set_physics_process(false)
	game.start_exploration(22)
	game.set_pause_reason("focus",false)
	enter(game,game.floor_data.rooms.keys().filter(func(id): return game.floor_data.rooms[id].role == "boss")[0])
	var boss = game.players[1]
	var player = game.players[0]
	# Every role remains reachable in both phases; selection is not one repeated fallback.
	for enraged in [false,true]:
		boss.prepare(Vector2(1000,600))
		boss.second_phase = enraged
		player.state.pos = Vector2(1300,600)
		var seen: Array = []
		var previous := ""
		for n in range(12):
			boss.attack_phase = "chase"
			boss.attack_time = 0
			boss.step(.01,1,player,game.arena)
			assert(boss.attack_phase == "windup")
			assert(boss.last_attack != previous)
			previous = boss.last_attack
			seen.append(boss.move_name)
		for move in ["dash","machinegun","salvo","cannon","shockwave"]: assert(move in seen)
	# Melee-range gaps and impassable margins skip directly to a usable ranged move.
	boss.prepare(Vector2(1000,600))
	assert(boss.choose_attack(Vector2(1120,600),game.arena).move == "slam")
	assert(boss.choose_attack(Vector2(1180,600),game.arena).move == "machinegun")
	boss.state.pos = Vector2(1080,1080)
	assert(boss.choose_attack(Vector2(890,1080),game.arena).move == "machinegun")
	var cursor: int = boss.move_index
	assert(boss.choose_attack(Vector2(200,200),game.arena).is_empty())
	assert(boss.move_index == cursor)
	# Existing mixed machinegun burst: tracking main stream + slower flanking rounds.
	for enraged in [false,true]:
		boss.prepare(Vector2(1000,600))
		boss.second_phase = enraged
		player.state.pos = Vector2(1300,650)
		boss.move_name = "machinegun"
		boss.attack_phase = "windup"
		boss.attack_time = 0
		boss.attack_angle = 0
		boss.step(.01,1,player,game.arena)
		assert(boss.attack_phase == "machinegun")
		assert(boss.emissions_left == (42 if enraged else 24))
		for n in range(180):
			boss.step(.016,1,player,game.arena)
			if boss.attack_phase == "recover": break
		assert(boss.attack_phase == "recover" and boss.attack_angle > 0)
		assert(game.shots.size() == (70 if enraged else 40))
		for shot in game.shots:
			assert(is_equal_approx(shot.damage,.85) and shot.cannon_blast_radius == 0)
			assert(shot.visual_variant == "boss_rivet")
		game.clear_field_objects()
	# A committed burst is paused exactly, and cancels if the whole boss leaves view.
	boss.attack_phase = "machinegun"
	boss.emissions_left = 10
	boss.emission_time = .05
	game.set_pause_reason("menu",true)
	game._physics_process(.5)
	assert(boss.emissions_left == 10 and boss.emission_time == .05)
	game.set_pause_reason("menu",false)
	player.state.pos = Vector2(100,100)
	boss.state.pos = Vector2(2000,900)
	boss.step(.01,1,player,game.arena)
	assert(boss.attack_phase == "chase" and boss.emissions_left == 0 and game.shots.is_empty())
	boss.prepare(Vector2(1000,600))
	assert(boss.last_attack.is_empty() and boss.move_index == 0)
	game.queue_free()
	await process_frame
	print("PASS: all boss attack roles, no immediate repetition, range/margin fallback, machinegun 40/70 shots, tracking, pause/offscreen cancel and reset")
	quit()
