extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func click(at: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = at
	motion.global_position = at
	root.push_input(motion,true)
	for pressed in [true,false]:
		var button := InputEventMouseButton.new()
		button.position = at
		button.global_position = at
		button.button_index = MOUSE_BUTTON_LEFT
		button.pressed = pressed
		root.push_input(button,true)
func run() -> void:
	var game = load("res://scenes/game/main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	var m = game.match_state
	assert(not m.place_expansion(0,"elbow",Vector2i(4,0)))
	m.stage = 5
	assert(m.expansion_pending(0) and m.expansion_pending(1))
	assert(m.capacity(0) == 16 and m.capacity(1) == 16)
	var old: Array = m.builds.duplicate(true)
	var picks: Array = m.remaining.duplicate()
	assert(not m.place_expansion(0,"unknown",Vector2i(4,0)))
	assert(not m.place_expansion(0,"elbow",Vector2i(0,0)))
	assert(not m.place_expansion(0,"rectangle",Vector2i(5,5)))
	assert(m.builds == old and m.remaining == picks)
	m.remaining = [0,0]
	assert(not m.confirm(0))
	var prep = game.preparation
	prep.refresh()
	await process_frame
	await process_frame
	var ready = prep.get_node("Root/Panel/Content/Ready")
	assert(ready.disabled and "拡張" in ready.text)
	var choices = prep.get_node("Root/Panel/Content/Cards/Rewards/Scroll/List")
	click(choices.get_node("Expansion_rectangle").get_global_rect().get_center())
	assert(prep.selected_expansion == "rectangle")
	assert(not prep.preview_expansion(Vector2i(0,0)))
	assert(prep.preview_expansion(Vector2i(0,4)))
	var grid = prep.get_node("Root/Panel/Content/Cards/Equipment/Grid")
	click(grid.get_child(24).get_global_rect().get_center())
	assert(prep.selected_expansion.is_empty())
	assert(m.capacity(0) == 22 and m.capacity(1) == 16)
	assert(m.usable_cells(0).has(Vector2i(2,5)) and not m.usable_cells(1).has(Vector2i(2,5)))
	assert(m.builds[0].owned == old[0].owned and m.remaining == [0,0])
	assert(not m.place_expansion(0,"elbow",Vector2i(4,0)))
	var token := "relic:18:900"
	m.builds[0].owned.append(token)
	assert(m.place(0,token,Vector2i(2,5)))
	m.builds[1].owned.append(token)
	assert(not m.place(1,token,Vector2i(2,5)))
	assert(m.confirm(0))
	prep.auto_prepare(1)
	assert(m.ready[1] and m.capacity(1) == 22)
	assert(m.builds[1].bag_expansion.shape == "elbow")
	game.launch_round()
	assert(game.phase == "play")
	assert(game.players[0].field_region.has(Vector2i(2,5)))
	assert(not game.players[1].field_region.has(Vector2i(2,5)))
	var snapshot: Dictionary = m.previous[0].duplicate(true)
	m.finish(-1,game.players)
	assert(m.builds[0].bag_expansion == snapshot.bag_expansion)
	m.start_round()
	m.finish(0,game.players)
	assert(not m.expansion_pending(0) and not m.expansion_pending(1))
	assert(m.previous[0] == snapshot)
	assert(m.remaining == [1,1])
	m.start_round()
	m.scores[0] = 2
	m.finish(0,game.players)
	assert(not m.builds[0].has("bag_expansion") and not m.previous[0].has("bag_expansion"))
	game.new_match(1)
	assert(m != game.match_state and game.match_state.capacity(0) == 6)
	game.queue_free()
	await process_frame
	print("PASS: separate free expansion, equal choices, atomic placement, GUI preview/click, per-player cells, CPU, field snapshot, draw/win/reset")
	quit()
