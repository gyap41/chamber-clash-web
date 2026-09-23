extends "res://tests/exploration_rooms.gd"

func enter(game, id: String) -> void:
	game.Encounter.retire(game)
	assert(game.switch_field(game.room_data(id).field).is_empty())
	game.exploration.enter_room(id,game.room_data(id).field.field_id)
	game.Encounter.begin(game)
	game.rebuild_doors()
	game.door_armed = true
	game.loot_message = ""
	game.refresh_hud()

func clear_room(game, id: String) -> void:
	enter(game,id)
	for enemy in game.players.slice(1): enemy.state.hp = 0
	game._physics_process(.01)
	assert(game.exploration.encounter_status == "cleared")

func run() -> void:
	root.size = Vector2i(1120,800)
	var game = load("res://scenes/game/exploration.tscn").instantiate()
	game.random_floor = true
	root.add_child(game)
	game.set_physics_process(false)
	game.start_exploration(22)
	game.set_pause_reason("focus",false)
	var treasure: String = game.floor_data.rooms.keys().filter(func(id): return game.floor_data.rooms[id].role == "treasure")[0]
	var normal: Array = game.floor_data.rooms.keys().filter(func(id): return game.floor_data.rooms[id].role == "normal")
	enter(game,treasure)
	assert(game.players.size() == 1)
	var chest: Dictionary = game.Reward.current(game)
	assert(chest.source == "treasure" and chest.state == "closed")
	game.players[0].state.pos = chest.pos+Vector2(0,45)
	game.players[0].sync_visual()
	game.fit_field_camera()
	game.refresh_hud()
	await capture("treasure-room")
	assert(game.try_chest())
	var chosen: int = chest.item
	clear_room(game,normal[0])
	assert(game.Reward.current(game).source == "first_clear") # Visiting treasure first does not consume the guarantee.
	assert(game.ExplorationSupplies.entries(game).is_empty())
	clear_room(game,normal[1])
	assert(game.ExplorationSupplies.entries(game).size() == 1)
	var ammo: Dictionary = game.ExplorationSupplies.entries(game)[0]
	var player = game.players[0]
	# Exercise finite ammunition with the shared actor policy disabled; infinite policy has its own test.
	player.exploration_starter = false
	player.state.pos = ammo.pos
	var w: Dictionary = player.weapon()
	var stock: int = player.definition().stock
	w.reserve = stock
	assert(game.try_supply() and not ammo.taken)
	w.reserve = 0
	w.clip = 1
	player.state.reload = .3
	game.door_armed = true
	game.set_pause_reason("menu",true)
	assert(not game.try_supply())
	game.set_pause_reason("menu",false)
	assert(game.try_supply() and ammo.taken)
	assert(w.reserve == ceili(stock*.4) and w.clip == 1 and player.state.reload == .3)
	var reserve: int = w.reserve
	assert(not game.try_supply() and w.reserve == reserve)
	assert(game.Loadout.apply(player,game.exploration.inventory,game.exploration.inventory.builds[0].duplicate(true),game.exploration.weapon_bank))
	assert(player.weapon().reserve == reserve)
	enter(game,treasure)
	assert(game.Reward.current(game).item == chosen and game.Reward.current(game).state == "open")
	game.players[0].state.pos = chest.pos+Vector2(0,45)
	assert(game.try_chest() and chest.state == "empty")
	clear_room(game,normal[2])
	assert(game.ExplorationSupplies.entries(game).size() == 1)
	assert(game.Reward.current(game).is_empty())
	var heal: Dictionary = game.ExplorationSupplies.entries(game)[0]
	player.state.pos = heal.pos
	player.state.hp = player.state.max_hp
	game.door_armed = true
	assert(game.try_supply() and not heal.taken)
	game.players[0].sync_visual()
	game.fit_field_camera()
	game.refresh_hud()
	await capture("supplies-available")
	player.state.hp -= 1
	player.rally_wounds.clear()
	player.rally_wounds.append({"amount":1.0,"time":2.0})
	game.door_armed = true
	assert(game.try_supply() and heal.taken)
	assert(player.state.hp == player.state.max_hp and player.rally_wounds.is_empty())
	game.players[0].sync_visual()
	game.fit_field_camera()
	game.refresh_hud()
	await capture("supplies-room")
	enter(game,normal[1])
	assert(game.ExplorationSupplies.entries(game)[0].taken and game.supply_nodes.is_empty())
	enter(game,normal[2])
	assert(game.ExplorationSupplies.entries(game)[0].taken)
	assert(not game.ExplorationSupplies.ensure(game))
	game.exploration.finish("dead")
	assert(not game.try_supply() and not game.try_chest())
	game.start_exploration(22)
	enter(game,treasure)
	assert(game.Reward.current(game).item == chosen and game.Reward.current(game).state == "closed")
	game.queue_free()
	await process_frame
	print("PASS: treasure-first guarantees, open/revisit/retry, supply cadence/full/partial/duplicate/pause, ammo bank and rally cap")
	quit()
