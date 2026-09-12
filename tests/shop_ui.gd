extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func click(at: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = at
	root.push_input(motion,true)
	for down in [true,false]:
		var event := InputEventMouseButton.new()
		event.position = at
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		root.push_input(event,true)
func run() -> void:
	var game = load("res://scenes/game/main.tscn").instantiate()
	root.add_child(game)
	preload("res://tests/helpers/battle.gd").passive_opponents(game)
	game.set_physics_process(false)
	var m = game.match_state
	var prep = game.preparation
	m._set_products(0,[18,"gun:1"])
	prep.refresh()
	await process_frame
	await process_frame
	var list = prep.get_node("Root/Panel/Content/Cards/Rewards/Scroll/List")
	var panel = list.get_children().filter(func(n): return n is PanelContainer)[0]
	var buy = panel.get_child(0).get_node("Claim")
	assert(buy.text == "2G 購入" and not buy.disabled)
	click(buy.get_global_rect().get_center())
	var token = m.builds[0].owned.back()
	assert(m.relic_id(token) == 18 and m.gold[0] == 10 and m.builds[0].equipped.is_empty())
	buy.pressed.emit() # queued second input from the same old card
	assert(m.gold[0] == 10 and m.builds[0].owned.size() == 2)
	await process_frame
	await process_frame
	list = prep.get_node("Root/Panel/Content/Cards/Rewards/Scroll/List")
	panel = list.get_children().filter(func(n): return n is PanelContainer)[0]
	assert(panel.get_child(0).get_node("Claim").disabled and panel.get_child(0).get_node("Claim").text == "売切")
	var grid = prep.get_node("Root/Panel/Content/Cards/Equipment/Grid")
	click(grid.get_child(0).get_global_rect().get_center())
	assert(m.builds[0].positions[token] == Vector2i.ZERO)
	await process_frame
	await process_frame
	grid = prep.get_node("Root/Panel/Content/Cards/Equipment/Grid")
	click(grid.get_child(0).get_global_rect().get_center())
	var sell = prep.detail_path().get_node("Discard")
	assert(sell.text == "売却 1G")
	click(sell.get_global_rect().get_center())
	assert(m.gold[0] == 11 and token not in m.builds[0].owned)
	m.temporary[0] = 19
	prep.refresh()
	await process_frame
	await process_frame
	list = prep.get_node("Root/Panel/Content/Cards/Rewards/Scroll/List")
	click(list.get_node("Refresh").get_global_rect().get_center())
	assert(m.gold[0] == 9 and m.temporary[0] == 19)
	await process_frame
	await process_frame
	list = prep.get_node("Root/Panel/Content/Cards/Rewards/Scroll/List")
	assert(list.get_node("Refresh").disabled)
	panel = list.get_children().filter(func(n): return n is PanelContainer)[0]
	assert(panel.get_child(0).get_node("Claim").text == "無料確保")
	click(panel.get_child(0).get_node("Claim").get_global_rect().get_center())
	assert(m.gold[0] == 9 and m.temporary[0] == -1 and m.relic_id(m.builds[0].owned.back()) == 19)
	assert(not prep.get_node("Root/Panel/Content/Ready").disabled)
	game.queue_free()
	await process_frame
	print("PASS: real shop purchase/sold/double input, click placement, sale, refresh and preserved free claim UI")
	quit()
