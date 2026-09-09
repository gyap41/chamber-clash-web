extends SceneTree
var events: Array = []
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var game = load("res://scenes/game/main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	var audio = game.sound
	var p = game.players[0]
	audio.played.connect(func(kind,id): events.append([kind,id]))
	audio.play_sound("shot")
	assert(events.is_empty())
	game.hud.get_node("SoundControls/Toggle").pressed.emit()
	assert(audio.enabled and events.back()[0] == "toggle")
	game.phase = "play"
	game.fire(0)
	assert(events.back() == ["shot",0])
	var count := events.size()
	game.fire(0)
	assert(events.size() == count)
	p.hurt(1)
	assert(events.back()[0] == "hit")
	p.state.inv = 0
	p.add_relic(3)
	p.hurt(1)
	assert(events.back()[0] == "bell")
	p.start_reload()
	assert(events.back()[0] == "reload")
	p.finish_reload()
	assert(events.back()[0] == "reload")
	p.state.reload = 0
	p.handle_key(KEY_SPACE,0,game.shots,game.players[1],game.arena)
	assert(events.back()[0] == "dodge")
	p.state.roll = 0
	# P1's melee is a right-click (2026-09-08), not the V key; try_melee() is the shared body
	# handle_key() itself now only reaches for P2's N key.
	p.try_melee(0,game.shots,game.players[1],game.arena)
	assert(events.back()[0] == "slash")
	game.use_pulse(0)
	assert(events.back()[0] == "boom")
	for id in range(20):
		var profile: Dictionary = audio.profile("shot",id)
		var stream: AudioStreamWAV = audio.synthesize(profile)
		assert(stream.data.size() == int(ceil(profile.duration*44100))*2)
		var nonzero := false
		for value in stream.data:
			if value != 0:
				nonzero = true
				break
		assert(nonzero)
	assert(audio.profile("shot",6).bandpass and audio.profile("shot",9).duration == .2)
	assert(audio.profile("boom",0).duration == .4)
	# Cache reuse and bounded overlapping voices.
	audio.play_sound("shot",0)
	var size: int = audio.cache.size()
	for i in range(20): audio.play_sound("shot",0)
	assert(audio.cache.size() == size and audio.voices.size() == 16)
	audio.set_enabled(false)
	assert(audio.voices.all(func(voice): return not voice.playing))
	count = events.size()
	audio.play_sound("hit")
	assert(events.size() == count)
	game.reset_round()
	assert(not audio.enabled)
	var bus: String = audio.bus_name
	game.queue_free()
	await process_frame
	assert(AudioServer.get_bus_index(bus) == -1)
	print("PASS: mute/UI/action guards/combat signals, 20 weapon synthesis profiles/PCM, cache/voice cap/stop and bus cleanup")
	quit()
