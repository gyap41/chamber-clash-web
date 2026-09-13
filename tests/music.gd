extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var music = root.get_node("Music")
	assert(music.player.playback_type == AudioServer.PLAYBACK_TYPE_STREAM)
	var title = load("res://scenes/ui/title.tscn").instantiate()
	root.add_child(title)
	assert(music.current_track == "title" and music.player.playing)
	var playback = music.player.get_stream_playback()
	title.start_cpu_match()
	assert(music.player.get_stream_playback() == playback)
	var select = root.get_children().filter(func(n): return n.get_script() == load("res://scripts/ui/character_select.gd"))[0]
	select.select_character(0)
	var game = root.get_children().filter(func(n): return n.get_script() == load("res://scripts/game/main.gd"))[0]
	game.set_physics_process(false)
	assert(music.current_track == "prepare")
	assert(music.player.stream.loop_end == 3790836)
	music.toggle.pressed.emit()
	assert(not music.enabled and music.player.stream_paused)
	preload("res://tests/helpers/battle.gd").start(game)
	assert(music.current_track == "play" and music.player.stream_paused)
	music.toggle.pressed.emit()
	assert(music.enabled and not music.player.stream_paused)
	game.paused = true
	game._process(0.0)
	assert(music.player.volume_db == -30.0)
	game.paused = false
	game._process(0.0)
	assert(music.player.volume_db == -22.0)
	game.players[1].state.hp = 0
	game._settle_round()
	assert(game.phase == "result" and not music.player.playing)
	game.reset_round()
	assert(music.current_track == "prepare" and music.player.playing)
	for key in music.streams:
		assert(music.streams[key].loop_mode == AudioStreamWAV.LOOP_FORWARD)
		assert(music.TRACKS[key].loop_mode == AudioStreamWAV.LOOP_DISABLED)
	game.free()
	music.play_context("result")
	await process_frame
	print("PASS: music scene continuity, phases, mute persistence, pause ducking, result stop, source isolation")
	quit()
