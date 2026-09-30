extends "res://tests/exploration_treasure_supplies.gd"

func run() -> void:
	var game = load("res://scenes/game/exploration.tscn").instantiate()
	game.random_floor = true
	root.add_child(game)
	game.set_physics_process(false)
	# Pools are rules over the catalog: no starter sidearm (0), no character-exclusive weapon,
	# and the early pool is the full pool without S rarity.
	var late: Array = game.Reward.weapon_pool(false)
	var early: Array = game.Reward.weapon_pool(true)
	for id in game.Weapons.SUPPORTED:
		var definition: Dictionary = game.Weapons.definition(id)
		assert((id in late) == (id != 0 and not definition.get("exclusive",false)),str(id))
		assert((id in early) == (id in late and definition.rarity != "S"),str(id))
	assert(not early.is_empty() and early.size() < late.size())
	var first_items: Array = []
	var previous: Array = []
	for seed_value in [22,22,41,73,104]:
		game.start_exploration(seed_value)
		game.set_pause_reason("focus",false)
		assert(not game.Reward.fits_bag(game.exploration,15,"weapon"))
		assert(not game.Reward.fits_bag(game.exploration,34,"weapon"))
		assert(not game.Reward.fits_bag(game.exploration,35,"weapon"))
		# Bag fit removes some candidates (34/35 above) but always leaves choices in both pools.
		var early_fit: Array = game.Reward.weapon_pool(true).filter(func(id): return game.Reward.fits_bag(game.exploration,id,"weapon"))
		var late_fit: Array = game.Reward.weapon_pool(false).filter(func(id): return game.Reward.fits_bag(game.exploration,id,"weapon"))
		assert(not early_fit.is_empty() and early_fit.size() < game.Reward.weapon_pool(true).size())
		assert(late_fit.size() > early_fit.size() and 34 not in late_fit and 35 not in late_fit)
		var normal: Array = game.floor_data.rooms.keys().filter(func(id): return game.floor_data.rooms[id].role == "normal")
		var treasure: Array = game.floor_data.rooms.keys().filter(func(id): return game.floor_data.rooms[id].role == "treasure")
		var initial_pool: Array = game.Reward.relic_pool(game.exploration)
		for id in [4,34,11,12,31,14,33,32,8,16,30]: assert(id not in initial_pool)
		clear_room(game,normal[0])
		var first: Dictionary = game.Reward.current(game).duplicate(true)
		assert(first.item in game.Reward.weapon_pool(true))
		assert(game.Reward.fits_bag(game.exploration,first.item,"weapon"))
		first_items.append(first.item)
		clear_room(game,normal[1])
		assert(game.Reward.current(game).is_empty())
		clear_room(game,normal[2])
		var third: Dictionary = game.Reward.current(game).duplicate(true)
		assert(third.source == "third_clear" and third.item != first.item)
		assert(game.Reward.fits_bag(game.exploration,third.item,"weapon"))
		assert(not game.Reward.ensure(game))
		var sequence: Array = [first.item,third.item]
		for room_id in treasure:
			enter(game,room_id)
			var reward: Dictionary = game.Reward.current(game)
			assert(reward.kind == "relic" and reward.item not in [4,34])
			assert(game.Reward.fits_bag(game.exploration,reward.item,"relic"))
			assert(reward.item not in sequence.slice(2))
			sequence.append(reward.item)
			assert(not game.Reward.ensure_treasure(game))
			var inventory = game.exploration.inventory
			var original: Dictionary = inventory.builds[0].duplicate(true)
			for id in range(38):
				inventory.store_field_weapon(0,id)
				if inventory.reserve_full(0): break
			assert(inventory.reserve_full(0))
			game.players[0].state.pos = reward.pos+Vector2(0,45)
			assert(game.try_chest())
			game.chest_node.step(1)
			game.door_armed = true
			assert(game.try_chest() and reward.state == "open")
			assert(not game.exploration.collected_loot.has(reward.id))
			inventory.builds[0] = original
			game.door_armed = true
			assert(game.try_chest() and reward.state == "empty")
			assert(reward.item in game.Reward.Items.relic_ids(inventory.builds[0].owned))
			assert(not game.try_chest())
			enter(game,normal[0])
			assert(game.Reward.current(game) == first)
			enter(game,room_id)
			assert(game.Reward.current(game).state == "empty")
		if seed_value == 22:
			if not previous.is_empty(): assert(sequence == previous)
			previous = sequence
	assert(first_items.any(func(id): return id != first_items[0]))
	game.queue_free()
	await process_frame
	print("PASS: reward pools, seed diversity/replay, first/third guarantees, unique reserved loot, relic capacity/collect/revisit")
	quit()
