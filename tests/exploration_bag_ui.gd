extends "res://tests/exploration_rooms.gd"
func click(point: Vector2) -> void:
	for pressed in [true,false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = point
		event.global_position = point
		root.push_input(event,true)
		await process_frame
func run() -> void:
	root.size = Vector2i(1120,800)
	var game = load("res://scenes/game/exploration.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.set_pause_reason("focus",false)
	for loot in game.room_loot():
		game.players[0].state.pos = loot.pos
		assert(game.try_collect_loot())
	await process_frame
	await process_frame
	game.set_pause_reason("focus",false)
	game.refresh_hud()
	await process_frame
	await click(Vector2(750,35))
	assert(game.bag != null and game.paused)
	var bag = game.bag
	var relic = bag.draft.reserve_items(0)[1]
	await click(bag.body.get_node("Bag/Reserve").get_child(1).get_global_rect().get_center())
	assert(bag.selected == relic)
	var target: Vector2i = bag.draft.auto_place(0,relic)
	await click(bag.body.get_node("Bag/Grid/Cell_%d_%d" % [target.x,target.y]).get_global_rect().get_center())
	assert(relic in bag.draft.builds[0].equipped)
	assert(relic in game.exploration.inventory.builds[0].equipped)
	assert(bag.body.get_node("Bag/Equipped").text == "バッグ ／ 使用 %d / %d マス" % [bag.draft.occupied_cells(0).size(),bag.draft.usable_cells(0).size()])
	assert(not bag.body.get_node("Bag").has_node("Apply"))
	bag.select(relic)
	assert("%dマス" % bag.draft.shape_of(relic).size() in bag.detail.text)
	await capture("bag-ui")
	await click(bag.body.get_node("Bag/Close").get_global_rect().get_center())
	assert(game.bag == null and not game.paused)
	assert(relic in game.exploration.inventory.builds[0].equipped)
	assert(not game.mouse_fire_held)
	game.queue_free()
	await process_frame
	print("PASS: actual GUI clicks open bag, select reserve, place immediately, show occupied cells and close without shooting")
	quit()
