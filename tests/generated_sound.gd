extends SceneTree
var events: Array = []
var playback_refs: Array = []
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var game = load("res://scenes/game/main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	var audio = game.sound
	audio.set_enabled(true)
	audio.played.connect(func(kind,id):
		events.append([kind,id])
		playback_refs.append(weakref(audio.voices[(audio.next_voice+15)%16].get_stream_playback())))
	assert(audio.GENERATED.size() == 50)
	for key in audio.GENERATED:
		assert(audio.GENERATED[key] is AudioStreamMP3)
		assert(not audio.GENERATED[key].loop)
	for pair in [[0,"pistol"],[20,"pistol"],[23,"heavy"],[26,"heavy"],[19,"rapid"],[27,"rapid"],[28,"rapid"],[3,"energy"],[6,"energy"],[7,"energy"],[36,"energy"]]:
		audio.play_sound("shot",pair[0])
		var voice = audio.voices[(audio.next_voice+15)%16]
		assert(voice.stream == audio.GENERATED[pair[1]])
		assert(voice.volume_db <= -12 and voice.bus == audio.bus_name)
	for id in range(38): assert(not audio.sample_key("shot",id).is_empty())
	assert(audio.sample_key("shot",999).is_empty())
	audio.play_sound("legacy_test",0)
	assert(audio.voices[(audio.next_voice+15)%16].stream is AudioStreamWAV)
	var prep = game.preparation
	var state = game.match_state
	state._set_products(0,["gun:1","gun:2",1,4,18])
	prep.refresh()
	prep.inspect_offer(state.products[0][2].id)
	assert(events.back()[0] == "ui_select")
	prep.buy_selected()
	assert(events.back()[0] == "ui_purchase")
	var entry = state.builds[0].owned.back()
	prep.select_entry(entry)
	prep.cancel_placement()
	assert(events.back()[0] == "ui_cancel")
	var count := events.size()
	prep.preview_at(entry,Vector2i(-1,-1))
	assert(events.size() == count)
	prep.place_relic(entry,Vector2i(-1,-1))
	assert(events.back()[0] == "ui_blocked")
	prep.place_relic(entry,state.auto_place(0,entry))
	assert(events.back()[0] == "ui_place")
	prep.ready_shop()
	assert(events.back()[0] == "ui_confirm")
	for winner in [0,1,-1]:
		game.new_match(42)
		game.phase = "play"
		game.players[0].state.hp = 0 if winner != 0 else 10
		game.players[1].state.hp = 0 if winner != 1 else 10
		count = events.size()
		game._settle_round()
		if winner < 0: assert(events.back()[0] == "draw")
		else: assert(events.back()[0] == ("win" if winner == 0 else "lose"))
		count = events.size()
		game._settle_round()
		assert(events.size() == count)
	game.new_match(42)
	preload("res://tests/helpers/battle.gd").start(game,1)
	preload("res://tests/helpers/battle.gd").passive_opponents(game)
	var supplies = game.supplies
	supplies.reset()
	supplies.legendary_chance = 1.0
	supplies.elapsed = supplies.legendary_time-5.01
	supplies.ammo_timer = 999
	supplies.supply_timer = 999
	supplies.relic_timer = 999
	events.clear()
	supplies.step(.02)
	assert(events == [["legendary",0]])
	supplies.step(.02)
	assert(events.size() == 1)
	supplies.elapsed = supplies.legendary_time-.01
	supplies.step(.02)
	assert(events.back()[0] == "chest_spawn")
	var chest = supplies.items.back()
	chest.age = 1.0
	game.players[0].state.pos = chest.position
	assert(supplies.acquire(0,chest,true))
	assert(events[-2][0] == "chest_open" and events[-1][0] == "rare_pickup")
	count = events.size()
	assert(not supplies.acquire(0,chest,true))
	assert(events.size() == count)
	game.remaining = game.round_duration-59.99
	game._physics_process(.02)
	assert(events.filter(func(e): return e[0] == "danger_warning").size() == 1)
	game._physics_process(.02)
	assert(events.filter(func(e): return e[0] == "danger_warning").size() == 1)
	count = events.size()
	audio.play_sound("start")
	assert(events.size() == count)
	game.remaining = 0
	game._settle_round()
	assert(events[-2][0] == "time_up")
	audio.set_enabled(false)
	assert(audio.voices.all(func(v): return not v.playing and v.stream == null))
	game.queue_free()
	await process_frame
	var deadline := Time.get_ticks_msec()+1000
	while playback_refs.any(func(ref): return ref != null and ref.get_ref() != null) and Time.get_ticks_msec() < deadline:
		await create_timer(.05).timeout
	assert(playback_refs.all(func(ref): return ref == null or ref.get_ref() == null))
	print("PASS: generated streams/routing/fallback/gain/UI outcomes/quiet preview/result once/mute")
	quit()
