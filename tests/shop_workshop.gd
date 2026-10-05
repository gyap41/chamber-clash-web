extends SceneTree
var game
func _initialize() -> void:
	call_deferred("run")
func capture(label: String) -> void:
	if "--capture" not in OS.get_cmdline_user_args(): return
	await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://.local/shop-workshop-"+label+".png") == OK)
func click(control: Control) -> void:
	var at: Vector2 = control.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = at
	motion.global_position = at
	root.push_input(motion,true)
	for pressed in [true,false]:
		var event := InputEventMouseButton.new()
		event.position = at
		event.global_position = at
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event,true)
func run() -> void:
	root.size = Vector2i(1120,800)
	game = load("res://scenes/game/exploration.tscn").instantiate()
	game.random_floor = true
	game.authored_campaign = true
	root.add_child(game)
	game.set_physics_process(false)
	game.set_pause_reason("focus",false)
	var shop: String = game.floor_data.rooms.keys().filter(func(id): return game.floor_data.rooms[id].role == "shop")[0]
	assert(game.move_to_room(shop,game.room_data(shop).doors[0].arrival))
	var inv = game.exploration.inventory
	inv.gold[0] = 100
	var stock: Array = game.exploration.room_state(shop).shop
	var item: Dictionary = stock.filter(func(value): return value.kind == "weapon")[0]
	assert(game.open_shop(item))
	var ui = game.shop_detail
	ui.set_process(false)
	await process_frame
	click(ui.buy_button)
	assert(not item.sold and inv.gold[0] == 100,"Opening blocks accidental purchase")
	ui._process(1.31)
	await capture("weapon")
	click(ui.buy_button)
	assert(item.sold and ui.purchased and game.paused)
	var balance: int = inv.gold[0]
	assert(balance == 100-item.price)
	click(ui.buy_button)
	assert(not game.confirm_shop_purchase() and inv.gold[0] == balance,"Animation cannot buy twice")
	ui._process(.7)
	await capture("purchase")
	ui._process(.51)
	assert(game.shop_detail == null and not game.pause_reasons.has("shop"))
	var upgrade: Dictionary = stock.filter(func(value): return value.kind == "expansion")[0]
	assert(game.open_shop(upgrade))
	ui = game.shop_detail
	ui.set_process(false)
	ui._process(1.31)
	var cell: Vector2i = inv.expansion_cells()[0]
	click(ui.get_node("ShopDetail/Expand_%d_%d" % [cell.x,cell.y]))
	assert(not ui.buy_button.disabled)
	await capture("expansion")
	click(ui.buy_button)
	assert(inv.usable_cells(0).has(cell) and ui.purchased and not upgrade.sold)
	ui.request_close()
	ui._process(.31)
	assert(game.shop_detail == null)
	inv.gold[0] = 0
	assert(game.open_shop(upgrade))
	ui = game.shop_detail
	ui.set_process(false)
	ui._process(1.31)
	assert(ui.buy_button.disabled and not ui.reason_label.text.is_empty())
	await capture("insufficient")
	game.close_shop()
	assert(not game.pause_reasons.has("shop"))
	print("PASS: workshop shop opening guard, purchase animation, duplicate prevention, expansion and insufficient funds")
	game.queue_free()
	await process_frame
	quit()
