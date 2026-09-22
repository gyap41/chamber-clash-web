extends "res://tests/fire_pouch_lizard.gd"
var events: Array[String] = []

func run() -> void:
	var game = load("res://scenes/game/exploration.tscn").instantiate()
	game.random_floor = true
	root.add_child(game)
	game.set_physics_process(false)
	game.start_exploration(22)
	game.set_pause_reason("focus",false)
	var ids: Array = game.floor_data.rooms.keys().filter(func(id): return game.floor_data.rooms[id].role == "normal")
	for index in range(2):
		game.Encounter.retire(game)
		game.exploration.enter_room(ids[index],game.room_data(ids[index]).field.field_id)
		game.switch_field(game.room_data(ids[index]).field)
		game.Encounter.begin(game)
	var sentry = game.players[1]
	var lizard = game.players[2]
	var player = game.players[0]
	for actor in [sentry,lizard]:
		actor.sound_requested.connect(func(kind, _id): events.append(kind))
	reset_pair(game,sentry)
	player.state.pos = Vector2(545,450)
	sentry.attack_time = 0
	sentry.step(0,1,player,game.arena)
	assert(events.count("sentry_windup") == 1)
	sentry.step(.1,1,player,game.arena)
	assert(events.count("sentry_windup") == 1)
	player.state.pos = Vector2(700,450) # A miss still swings, without a contact sound.
	sentry.step(1,1,player,game.arena)
	assert(events.count("sentry_swing") == 1)
	assert(sentry.hurt(99))
	assert(not sentry.hurt(99))
	sentry.attack_phase = "windup"
	sentry.attack_time = 0
	sentry.step(1,1,player,game.arena)
	assert(events.count("sentry_down") == 1 and events.count("sentry_swing") == 1)
	reset_pair(game,lizard)
	lizard.attack_time = 0
	lizard.step(0,2,player,game.arena)
	assert(events.count("lizard_inhale") == 1)
	lizard.step(.81,2,player,game.arena)
	lizard.step(.23,2,player,game.arena)
	assert(events.count("lizard_spit") == 2)
	reset_pair(game,lizard)
	lizard.attack_time = 0
	lizard.step(0,2,player,game.arena)
	player.state.pos = Vector2(1500,900)
	lizard.step(1,2,player,game.arena)
	assert(events.count("lizard_spit") == 2) # Offscreen cancellation is silent.
	assert(lizard.hurt(99))
	assert(not lizard.hurt(99))
	assert(events.count("lizard_down") == 1 and events.count("sentry_down") == 1)
	var sound = game.sound
	for kind in ["sentry_swing","sentry_down","lizard_down"]:
		assert(sound.sample_key(kind) == kind)
		assert(sound.GENERATED[kind].get_length() > 0)
	var played: Array[String] = []
	sound.played.connect(func(kind, _id): played.append(kind))
	sound.contact_times.clear()
	sound.play_sound("lizard_spit")
	sound.play_sound("lizard_spit")
	assert(played.size() == 1)
	sound.set_enabled(false)
	sound.play_sound("sentry_windup")
	assert(played.size() == 1)
	for voice in sound.voices: assert(not voice.playing)
	game.queue_free()
	await process_frame
	print("PASS: enemy sound timing, cancellation, death, coalescing and mute")
	quit()
