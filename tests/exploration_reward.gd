extends "res://tests/exploration_rooms.gd"
func run() -> void:
	root.size = Vector2i(1120,800)
	var game = load("res://scenes/game/exploration.tscn").instantiate()
	game.random_floor = true
	root.add_child(game)
	game.set_physics_process(false)
	game.start_exploration(22)
	game.set_pause_reason("focus",false)
	var id: String = game.floor_data.rooms.keys().filter(func(room): return game.floor_data.rooms[room].role == "normal")[0]
	game.Encounter.retire(game)
	game.switch_field(game.room_data(id).field)
	game.exploration.enter_room(id,game.room_data(id).field.field_id)
	game.Encounter.begin(game)
	game.rebuild_doors()
	for enemy in game.players.slice(1): enemy.state.hp = 0
	game._physics_process(.01)
	var reward: Dictionary = game.Reward.current(game)
	assert(not reward.is_empty() and reward.state == "closed")
	assert(not game.Reward.ensure(game))
	assert(not game.arena.solid(reward.pos,24))
	game.players[0].state.pos = reward.pos+Vector2(0,45)
	game.players[0].sync_visual()
	game.fit_field_camera()
	game.chest_node.spawning = 0
	game.refresh_hud()
	await capture("reward-closed")
	assert(game.try_chest() and reward.state == "open")
	assert(game.try_chest() and not game.exploration.collected_loot.has(reward.id))
	var timer: float = game.chest_node.opening
	game.set_pause_reason("inventory",true)
	game._physics_process(.2)
	assert(game.chest_node.opening == timer and not game.try_chest())
	game.set_pause_reason("inventory",false)
	game.chest_node.step(.4)
	game.door_armed = true
	game.refresh_hud()
	await capture("reward-open")
	# Acquisition refusal leaves the contents available; reopening does not reroll.
	var inventory = game.exploration.inventory
	var original: Dictionary = inventory.builds[0].duplicate(true)
	for item in range(38):
		if item != reward.item: inventory.store_field_weapon(0,item)
		if inventory.reserve_full(0): break
	assert(inventory.reserve_full(0))
	assert(game.try_chest() and reward.state == "open")
	inventory.builds[0] = original
	game.rebuild_chest()
	assert(game.Reward.current(game) == reward and game.chest_node.opening == 0)
	game.door_armed = true
	assert(game.try_chest() and reward.state == "empty")
	assert(game.exploration.collected_loot.has(reward.id))
	assert(not game.try_chest())
	game.rebuild_chest()
	assert(game.chest_node.reward.state == "empty")
	game.start_exploration(22)
	assert(game.exploration.room_states.values().all(func(room): return not room.has("reward")))
	game.exploration.encounter_status = "active"
	game.exploration.settle(false,false)
	assert(not game.Reward.ensure(game))
	game.queue_free()
	await process_frame
	print("PASS: first-clear chest, open/collect, latch, pause, refusal, rebuild, retry and death priority")
	quit()
