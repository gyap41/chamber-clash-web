extends SceneTree
const Events = preload("res://scripts/game/exploration_events.gd")
const Coins = preload("res://scripts/game/exploration_coins.gd")
var game
func _initialize() -> void:
	call_deferred("run")
func capture(label: String) -> void:
	if "--capture" not in OS.get_cmdline_user_args(): return
	await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://.local/feedback-"+label+".png") == OK)
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
	var inventory = game.exploration.inventory
	inventory.gold[0] = 100
	var stock: Array = game.exploration.room_state(shop).shop
	var item: Dictionary = stock.filter(func(value): return value.kind == "weapon")[0]
	game.players[0].state.pos = item.pos
	game.players[0].sync_visual()
	game.door_armed = true
	assert(Events.use(game) and game.shop_detail != null and game.paused)
	assert(not item.sold and inventory.gold[0] == 100,"Inspecting never purchases")
	assert("基礎威力" in game.shop_detail.get_node("ShopDetail/Description").text)
	await capture("shop")
	game.close_shop()
	if "--capture" in OS.get_cmdline_user_args():
		game.players[0].state.pos = game.exploration.room_state(shop).shop_sign+Vector2(0,40)
		game.players[0].sync_visual()
		game.FollowCamera.follow(game.arena.get_node("CombatCamera"),game.arena.field_rect,game.players[0].state.pos,true)
		game.door_armed = true
		assert(Events.use(game))
		assert("煤の帳守" in game.loot_message)
		game.refresh_hud()
		await capture("merchant")
	assert(not item.sold and inventory.gold[0] == 100,"Cancel is free")
	var upgrade: Dictionary = stock.filter(func(value): return value.kind == "expansion")[0]
	game.players[0].state.pos = upgrade.pos
	assert(game.open_shop(upgrade))
	var cells: Array = inventory.expansion_cells()
	assert(not cells.is_empty() and Vector2i(5,5) not in cells)
	assert(game.shop_detail.buy_button.disabled)
	upgrade.cell = cells[0]
	game.shop_detail.refresh()
	assert(not game.shop_detail.buy_button.disabled)
	await capture("expansion")
	assert(game.confirm_shop_purchase())
	assert(inventory.capacity(0) == 9 and inventory.gold[0] == 92 and not upgrade.sold and upgrade.price == 10)
	assert(not inventory.buy_cell(cells[0],10) and inventory.gold[0] == 92,"Cannot buy the same cell twice")
	assert(game.open_bag())
	game.bag.select(inventory.builds[0].owned[0])
	assert("0.55" in game.bag.detail.text and "予備 ∞" in game.bag.detail.text)
	await capture("bag")
	game.close_bag()
	# Distant money returns automatically after victory, with no duplicate payout.
	game.exploration.encounter_status = "cleared"
	var list: Array = Coins.entries(game)
	list.append({"id":"test_far","pos":Vector2(50,50),"value":2,"age":1.0})
	game.players[0].state.pos = Vector2(800,600)
	for frame in range(180): Coins.step(game,1.0/60)
	assert(list.is_empty() and inventory.gold[0] == 94)
	Coins.step(game,1.0)
	assert(inventory.gold[0] == 94)
	for id in game.floor_data.rooms:
		assert(Events.has_teleporter(game,id) == (game.floor_data.rooms[id].role != "boss"))
	var hero = game.players[0]
	hero.weapon().clip = 0
	hero.start_reload()
	hero.sync_visual()
	assert(hero.get_node("ReloadProgress").visible)
	hero.state.reload = 0
	hero.sync_visual()
	assert(not hero.get_node("ReloadProgress").visible)
	var duplicate = game.Loadout.draft(inventory)
	while not duplicate.expansion_cells().is_empty():
		assert(duplicate.buy_cell(duplicate.expansion_cells()[0],0))
	assert(duplicate.capacity(0) == 24 and inventory.capacity(0) == 9)
	assert(not duplicate.buy_cell(Vector2i(5,5),0))
	var ammo: Dictionary = stock.filter(func(value): return value.kind == "ammo")[0]
	assert(not Events.purchase_reason(game,ammo).is_empty())
	assert(game.open_shop(upgrade))
	game.start_exploration(765)
	assert(game.shop_detail == null and not game.pause_reasons.has("shop"))
	print("PASS: inspect/cancel, expansion transaction and persistence, distant coin recovery, pads and overhead reload")
	game.queue_free()
	await process_frame
	quit()
