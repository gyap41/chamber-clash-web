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
	await click(game.hud.get_node("Root/Bag").get_global_rect().get_center())
	assert(game.bag != null and game.paused)
	var bag = game.bag
	bag.set_process(false)
	assert(not bag.can_interact())
	bag.advance_animation(.5)
	assert(bag.can_interact())
	var animation_time: float = bag.time
	var relic = bag.draft.reserve_items(0)[1]
	await click(bag.body.get_node("Bag/Reserve/Item_1").get_global_rect().get_center())
	assert(bag.selected == relic)
	var target: Vector2i = bag.draft.auto_place(0,relic)
	await click(bag.body.get_node("Bag/Grid/Cell_%d_%d" % [target.x,target.y]).get_global_rect().get_center())
	assert(relic in bag.draft.builds[0].equipped)
	assert(relic in game.exploration.inventory.builds[0].equipped)
	assert(not bag.body.get_node("Bag").has_node("Equipped"))
	assert(bag.time == animation_time) # Layout refresh does not replay opening.
	assert(not bag.body.get_node("Bag").has_node("Apply"))
	bag.select(relic)
	assert("必要な面積" not in bag.detail.text)
	assert(not bag.detail.text.is_empty())
	bag.advance_animation(.2)
	await capture("bag-ui")
	await click(bag.body.get_node("Close").get_global_rect().get_center())
	assert(game.bag == bag and game.paused and bag.closing)
	assert(not bag.can_interact())
	bag.advance_animation(.25)
	assert(game.bag == null and not game.paused)
	assert(relic in game.exploration.inventory.builds[0].equipped)
	assert(not game.mouse_fire_held)
	game.queue_free()
	await process_frame
	print("PASS: actual GUI clicks open bag, select reserve, place immediately, keep animation stable, omit redundant labels, animate close without shooting")
	quit()
