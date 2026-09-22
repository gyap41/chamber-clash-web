extends "res://tests/exploration_rooms.gd"
const Loadout = preload("res://scripts/game/exploration_loadout.gd")
func run() -> void:
	root.size = Vector2i(1120,800)
	var game = load("res://scenes/game/exploration.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.set_pause_reason("focus",false)
	var player = game.players[0]
	var inv = game.exploration.inventory
	player.hurt(2)
	player.weapon().clip = 2
	player.weapon().reserve = 7
	player.weapon().mode = 1
	player.start_reload()
	player.state.reload *= .5
	player.state.shot = .4
	player.state.dodge = .8
	player.state.empty_casing_charge = true
	var hp: float = player.state.hp
	var reload_time: float = player.state.reload
	var token: String = inv.gun_token(player.weapon().id)
	var position: Vector2i = inv.builds[0].positions[token]
	assert(game.open_bag() and game.paused)
	var before := snapshot(player,inv)
	game._physics_process(2)
	assert(snapshot(player,inv) == before)
	assert(game.close_bag())
	assert(snapshot(player,inv) == before and not game.paused)
	# Unequip and re-equip preserves ammunition/mode, unfinished reload and charges.
	assert(game.open_bag())
	assert(game.bag.remove(token))
	assert(not player.has_weapon())
	assert(game.close_bag() and not player.has_weapon())
	assert(game.open_bag())
	assert(game.bag.place(token,position))
	assert(game.close_bag())
	assert(player.weapon().clip == 2 and player.weapon().reserve == 7 and player.weapon().mode == 1)
	assert(player.state.reload == reload_time and player.state.shot == .4 and player.state.dodge == .8)
	assert(player.state.empty_casing_charge and player.state.hp == hp)
	# Invalid/forged draft cannot mutate the live build or combat resources.
	assert(game.open_bag())
	var draft = game.bag.draft
	draft.builds[0].positions[token] = Vector2i(5,5)
	before = snapshot(player,inv)
	assert(not game.apply_bag_changes())
	assert(snapshot(player,inv) == before)
	game.close_bag()
	# Pickup enters reserve once, can be placed immediately, and survives revisits.
	for loot in game.room_loot():
		player.state.pos = loot.pos
		assert(game.try_collect_loot())
	assert(game.exploration.collected_loot.size() == 2)
	assert(game.loot_nodes.is_empty())
	assert(inv.reserve_items(0).size() == 2)
	assert(game.open_bag())
	await capture("bag-reserve")
	var relic = inv.reserve_items(0).filter(func(entry): return inv.is_relic(entry))[0]
	var anchor: Vector2i = game.bag.draft.auto_place(0,relic)
	assert(anchor.x >= 0 and game.bag.place(relic,anchor))
	assert(game.close_bag())
	assert(player.state.hp == hp and player.state.max_hp > player.max_hp)
	assert(game.open_bag())
	assert(game.bag.remove(relic))
	assert(game.close_bag())
	assert(player.state.hp == hp)
	# Equip the picked-up weapon, then switch back; the first gun is not replenished.
	assert(game.open_bag())
	assert(game.bag.remove(token))
	assert(not player.has_weapon())
	var picked := "gun:1"
	assert(game.bag.place(picked,game.bag.draft.auto_place(0,picked)))
	assert(game.close_bag() and player.weapon().id == 1)
	player.weapon().clip = 1
	assert(game.open_bag())
	assert(game.bag.remove(picked))
	assert(game.bag.place(token,position))
	assert(game.close_bag())
	assert(player.weapon().clip == 2 and player.state.reload == reload_time)
	# Keyboard/wheel/HUD all route through apply_command, preserving pending reload.
	assert(game.open_bag())
	assert(game.bag.place(picked,game.bag.draft.auto_place(0,picked)))
	assert(game.close_bag())
	var primary_slot: int = player.state.gun
	var other_slot: int = 1-primary_slot
	game.apply_command(0,{"switch":other_slot})
	assert(player.weapon().id == 1 and player.weapon().clip == 1)
	game.apply_command(0,{"switch":primary_slot})
	assert(player.weapon().clip == 2 and player.state.reload == reload_time)
	assert(game.open_bag())
	assert(game.bag.remove(picked))
	assert(game.close_bag())
	# Other pause reasons remain after closing inventory.
	assert(game.open_bag())
	game.set_pause_reason("focus",true)
	assert(game.close_bag() and game.paused)
	game.set_pause_reason("focus",false)
	assert(game.fire_requires_release)
	before = snapshot(player,inv)
	for id in ["east","west"]:
		player.state.pos = game.room_data(game.exploration.room_id).doors[0].position
		key(game,false); key(game,true); key(game,false)
	assert(game.exploration.room_id == Rooms.START_ROOM)
	assert(game.loot_nodes.is_empty() and inv.reserve_items(0).size() == 2)
	assert(snapshot(player,inv) == before)
	player.state.hp = 0
	assert(not game.open_bag())
	game.start_exploration(22)
	assert(game.exploration.collected_loot.is_empty() and game.loot_nodes.size() == 2)
	assert(game.exploration.weapon_bank.size() == 1)
	assert(game.open_bag())
	await capture("bag-start")
	game.close_bag()
	# A full reserve leaves the pickup on the floor and unequip is rejected.
	for i in range(8): game.exploration.inventory._acquire(0,0,"test",0,"")
	player.state.pos = game.room_loot()[0].pos
	assert(game.try_collect_loot())
	assert(game.exploration.collected_loot.is_empty() and game.loot_nodes.size() == 2)
	assert(game.open_bag())
	assert(not game.bag.remove(token))
	game.close_bag()
	game.queue_free()
	await process_frame
	print("PASS: inventory pause/immediate changes/close, atomic rejection, unarmed/re-equip resources, HP limit, pickups, revisit, focus and restart")
	quit()
