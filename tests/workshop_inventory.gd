extends "res://tests/footprint_balance.gd"
var cues: Array = []
func check_opening_audio(audio) -> void:
	assert(audio.sample_key("workshop_open")=="workshop_open")
	var stream: AudioStreamWAV = audio.GENERATED["workshop_open"]
	assert(stream.stereo and stream.mix_rate==44100 and stream.loop_mode==AudioStreamWAV.LOOP_DISABLED)
	assert(stream.format==AudioStreamWAV.FORMAT_16_BITS,"Keep the adopted mix as original PCM")
	assert(absf(stream.get_length()-.83)<.001)
	var peak: float = 0.0
	for i in range(stream.data.size()/2):
		peak = maxf(peak,absf(float(stream.data.decode_s16(i*2))/32768))
	assert(peak>.02 and peak<.8,"Adopted opening is non-silent and has headroom")
	for byte_offset in [0,2,stream.data.size()-4,stream.data.size()-2]:
		assert(stream.data.decode_s16(byte_offset)==0)
	if "--capture-audio" in OS.get_cmdline_user_args():
		assert(stream.save_to_wav("res://.local/workshop-open-review.wav")==OK)
func drag_to(source: Vector2,target: Vector2) -> void:
	motion(source)
	button(source,true)
	motion(source+Vector2(20,0),true,Vector2(20,0))
	await process_frame
	assert(root.gui_is_dragging())
	motion(target,true,target-source-Vector2(20,0))
	await process_frame
	button(target,false)
	await process_frame
func run() -> void:
	root.size = Vector2i(1120,800)
	var game = load("res://scenes/game/exploration.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.set_pause_reason("focus",false)
	game.sound.enabled = true
	check_opening_audio(game.sound)
	game.sound.played.connect(func(kind: String,_id: int): cues.append(kind))
	var inv = game.exploration.inventory
	assert(inv.store_field_relic(2))
	assert(game.open_bag())
	var bag = game.bag
	bag.set_process(false)
	var relic = bag.draft.reserve_items(0).back()
	var anchor: Vector2i = bag.draft.auto_place(0,relic)
	assert(not bag.user_place(relic,anchor))
	assert(relic not in inv.builds[0].equipped)
	bag.advance_animation(.7)
	assert(bag.can_interact())
	assert(cues.count("workshop_open")==1)
	assert(cues.count("workshop_drive")==0 and cues.count("workshop_power")==0 and cues.count("workshop_latch")==0)
	var opening_voice = game.sound.voices.filter(func(voice): return voice.get_meta("kind","")=="workshop_open")[0]
	assert(opening_voice.stream==game.sound.GENERATED["workshop_open"])
	assert(opening_voice.volume_db==game.sound.volume_db and opening_voice.pitch_scale==1.0)
	await process_frame
	# Initial detail selection is not permission to move the starter or show a ghost.
	var empty: Vector2 = bag.panel.get_node("Grid/Cell_3_1").get_global_rect().get_center()
	motion(empty)
	await process_frame
	bag.update_hover(Vector2(209,89))
	assert(not bag.hover_preview.visible and not bag.placement_armed)
	var starter = bag.selected
	var original: Vector2i = bag.draft.builds[0].positions[starter]
	button(empty,true); button(empty,false)
	await process_frame
	assert(bag.draft.builds[0].positions[starter]==original)
	# An explicit click does arm placement, without changing equipment yet.
	var reserve_center: Vector2 = bag.panel.get_node("Reserve/Item_0").get_global_rect().get_center()
	motion(reserve_center)
	await process_frame
	button(reserve_center,true)
	await process_frame
	button(reserve_center,false)
	await process_frame
	motion(empty)
	await process_frame
	bag.update_hover(Vector2(209,89))
	assert(bag.placement_armed and bag.hover_preview.visible)
	# Invalid drop onto a closed cell does not change inventory.
	var source: Vector2 = bag.panel.get_node("Reserve/Item_0").get_global_rect().get_center()
	var invalid: Vector2 = bag.panel.get_node("Grid/Cell_5_5").get_global_rect().get_center()
	await drag_to(source,invalid)
	assert(relic not in inv.builds[0].equipped)
	bag.update_hover(Vector2(209,89))
	assert(not bag.hover_preview.visible and not bag.placement_armed)
	var target: Vector2 = bag.panel.get_node("Grid/Cell_%d_%d" % [anchor.x,anchor.y]).get_global_rect().get_center()
	await drag_to(source,target)
	assert(relic in inv.builds[0].equipped and inv.builds[0].positions[relic]==anchor)
	bag.update_hover(Vector2(209,89))
	assert(not bag.hover_preview.visible and not bag.placement_armed)
	assert(bag.time==.7 and cues.count("workshop_open")==1)
	# Grab a non-origin cell, preserve its offset, and remove by dropping into the tray.
	var offset: Vector2i = bag.draft.shape_of(relic).back()
	var cell: Vector2i = anchor+offset
	source = bag.panel.get_node("Grid/Cell_%d_%d" % [cell.x,cell.y]).get_global_rect().get_center()
	target = bag.panel.get_node("Reserve").get_global_rect().get_center()
	await drag_to(source,target)
	assert(relic in inv.reserve_items(0))
	assert("必要な面積" not in bag.detail.text)
	assert(not bag.panel.has_node("Title") and not bag.panel.has_node("Equipped"))
	# Closing while dragging cancels the preview, locks writes, and keeps the game paused.
	source = bag.panel.get_node("Reserve/Item_0").get_global_rect().get_center()
	motion(source); button(source,true); motion(source+Vector2(20,0),true,Vector2(20,0))
	await process_frame
	assert(root.gui_is_dragging())
	game.request_close_bag()
	game.request_close_bag()
	assert(not root.gui_is_dragging() and game.paused and not bag.can_interact())
	assert(not bag.place(relic,anchor))
	assert(cues.count("workshop_close")==1)
	game.set_pause_reason("focus",true)
	bag.advance_animation(.25)
	assert(game.bag==null and game.paused and game.fire_requires_release)
	for voice in game.sound.voices:
		if str(voice.get_meta("kind","")).begins_with("workshop_"): assert(not voice.playing)
	game.set_pause_reason("focus",false)
	# Interrupt a fresh opening before the energy layer at 350ms.
	assert(game.open_bag())
	bag = game.bag
	bag.set_process(false)
	bag.advance_animation(.15)
	game.request_close_bag()
	for voice in game.sound.voices:
		if voice.get_meta("kind","")=="workshop_open": assert(not voice.playing)
	bag.advance_animation(.25)
	assert(game.bag==null and not game.paused)
	game.sound.set_enabled(false)
	var before: int = cues.size()
	assert(game.open_bag())
	bag = game.bag
	bag.set_process(false)
	bag.advance_animation(.7)
	assert(cues.size()==before)
	game.close_bag()
	game.queue_free()
	await process_frame
	print("PASS: workshop GUI drags, invalid cell rejection, reserve drop, animation gates/cues/cancel/mute, focus and no redundant labels")
	quit()
