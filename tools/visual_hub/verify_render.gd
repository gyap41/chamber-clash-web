extends SceneTree
const Store = preload("res://tools/visual_hub/conditions.gd")
var hub
var prior_settings: Dictionary
func _initialize() -> void: call_deferred("run")
func screenshot(name: String) -> Image:
	await process_frame
	await RenderingServer.frame_post_draw
	var image:=root.get_texture().get_image()
	assert(image.save_png(Store.DIRECTORY+"/"+name+".png")==OK)
	return image
func run() -> void:
	prior_settings=Store.read(Store.SETTINGS)
	hub=load("res://tools/visual_hub/visual_hub.tscn").instantiate(); root.add_child(hub)
	hub.state=Store.defaults(); hub._restore_controls(); hub.reload_index()
	for n in range(12): await process_frame
	await screenshot("ui-character")
	# Route mouse press/release through the actual viewport and Control hit testing.
	for pressed in [true,false]:
		var event := InputEventMouseButton.new(); event.button_index=MOUSE_BUTTON_LEFT; event.pressed=pressed; event.position=hub.play_button.get_global_rect().get_center()
		root.push_input(event,true)
		await process_frame
	assert(hub.state.playing,"Play button responds to pointer input")
	hub.state.playing=false
	hub.state.compare=["character:0","character:1","character:2","character:7"]; hub.state.screen="比較"; hub.state.action="回避"; hub.state.zoom=2.0; hub.state.sync="進捗"; hub.state.background="透過"
	hub._restore_controls(); hub._comparison_list(); hub._rebuild_previews()
	for n in range(22): hub._advance(1.0/60); await process_frame
	await screenshot("ui-compare-characters")
	var paused:=await screenshot("pause-a")
	for n in range(8): await process_frame
	var still:=await screenshot("pause-b")
	var rect:=Rect2i(hub.grid.get_global_rect())
	assert(paused.get_region(rect).get_data()==still.get_region(rect).get_data(),"Pause pixels identical")
	hub._advance(1.0/60)
	var stepped:=await screenshot("step")
	assert(paused.get_region(rect).get_data()!=stepped.get_region(rect).get_data(),"Single step changes pixels")
	hub.state.playing=true
	for n in range(8): await process_frame
	hub.state.playing=false
	assert(hub.state.time>23.0/60,"Playback resumed")
	print("PASS: actual Compatibility character compare / pause exact pixels / single step / resume")
	hub.state.compare=["weapon:4","weapon:10","weapon:20","weapon:37"]; hub.state.action="連射"; hub.state.category="武器"; hub.state.selected="weapon:10"; hub.state.fit=true; hub.state.background="実戦"; hub.state.guides=true
	hub._restore_controls(); hub._list(); hub._detail(); hub._comparison_list(); hub._rebuild_previews()
	for n in range(130): hub._advance(1.0/60); await process_frame
	await screenshot("ui-compare-weapons")
	var well_pause:=await screenshot("well-pause-a")
	for n in range(8): await process_frame
	var well_still:=await screenshot("well-pause-b")
	assert(well_pause.get_region(rect).get_data()==well_still.get_region(rect).get_data(),"Gravity particles pause")
	await hub.capture()
	var replay_path:=Store.DIRECTORY+"/render-restore.json"
	Store.save(replay_path,{"conditions":hub.state.duplicate(true),"catalog_hash":hub.index.fingerprint})
	hub.restore_conditions(replay_path)
	while hub.replay_target>=0: await process_frame
	var replayed:=await screenshot("well-replayed")
	assert(well_pause.get_region(rect).get_data()==replayed.get_region(rect).get_data(),"Seek resimulates full particle and trajectory history")
	print("PASS: saved conditions restore and gravity/trajectory resimulation pixel equality")
	print("PASS: four weapon viewports / gravity background lens and particles pause / PNG+conditions")
	hub.state.compare=["stage:duel","stage:validation"]; hub.state.category="ステージ"; hub.state.selected="stage:validation"; hub.state.action="待機"
	hub._restore_controls(); hub._list(); hub._detail(); hub._comparison_list(); hub._rebuild_previews()
	await screenshot("ui-stages")
	for name in ["movement_bounds","bullet_bounds","spawns","supplies"]:
		hub.controls[name].button_pressed=false
		assert(not hub.state[name])
	await screenshot("ui-stages-clean")
	hub.state.screen="単体"; hub.state.category="レリック"; hub.state.selected="relic:0"; hub.state.fit=false; hub.state.zoom=4.0; hub._restore_controls(); hub._list(); hub._detail(); hub._rebuild_previews()
	await screenshot("ui-relic")
	print("PASS: stage overlays toggle; relic UI; rendered UI snapshots saved")
	hub.state.category="武器"; hub.state.selected="weapon:37"; hub.state.action="リロード"; hub.state.icon=false; hub.state.zoom=3.0
	hub._restore_controls(); hub._list(); hub._detail(); hub._rebuild_previews()
	for n in range(30): hub._advance(1.0/60); await process_frame
	await screenshot("ui-reload")
	# Recreate the whole Hub, verifying local last-screen and time persistence.
	hub.state.time=0.5; hub.state.query="weapon:37"; hub.state.playing=false
	hub.free(); hub=load("res://tools/visual_hub/visual_hub.tscn").instantiate(); root.add_child(hub)
	while hub.replay_target>=0: await process_frame
	assert(hub.state.selected=="weapon:37" and hub.state.query=="weapon:37" and is_equal_approx(hub.state.time,0.5),"Application restart restores conditions")
	assert(hub.previews[0].adapter.players[0].state.reload>0,"Reload state restored")
	# Test removed identities and preserving valid comparison targets on reload.
	hub.state.selected="weapon:999"; hub.state.compare=["weapon:999","weapon:37"]
	hub.reload_index(); assert(hub.state.compare==["weapon:37"] and hub.state.selected!="weapon:999")
	assert(hub.status_label.text.contains("削除された対象"))
	while hub.replay_target>=0: await process_frame
	root.size=Vector2i(1120,760)
	for n in range(4): await process_frame
	await screenshot("ui-minimum-window")
	await hub.capture()
	assert(hub.status_label.text.begins_with("PNGと条件保存"))
	print("PASS: pointer input, app restart/time restore, removed selection, minimum-window PNG capture")
	hub.free()
	Store.save(Store.SETTINGS,prior_settings)
	await process_frame
	quit()
