extends "res://tests/exploration_treasure_supplies.gd"

func run() -> void:
	root.size = Vector2i(1120,800)
	var game = load("res://scenes/game/exploration.tscn").instantiate()
	game.random_floor = true
	root.add_child(game)
	game.set_physics_process(false)
	game.start_exploration(22)
	game.set_pause_reason("focus",false)
	var room: String = game.floor_data.rooms.keys().filter(func(id): return game.floor_data.rooms[id].role == "boss")[0]
	enter(game,room)
	var boss = game.players[1]
	var player = game.players[0]
	assert(game.boss_intro() and boss.attack_time == 2.4)
	assert(game.get_node("/root/Music").current_track.is_empty())
	var pos: Vector2 = player.state.pos
	game.apply_command(0,{"fire_pressed":true,"pulse":true})
	assert(game.shots.is_empty() and not boss.hurt(100))
	game.set_pause_reason("focus",true)
	game._physics_process(.5)
	game.BossFlow.finish_intro(game)
	assert(boss.attack_time == 2.4 and game.boss_intro())
	game.set_pause_reason("focus",false)
	game._physics_process(1.0)
	assert(player.state.pos == pos and game.boss_intro())
	await capture("boss-startup")
	game.BossFlow.finish_intro(game)
	assert(not game.boss_intro() and game.get_node("/root/Music").current_track == "boss")
	assert(not game.mouse_fire_held)
	var sounds: Array = []
	game.sound.played.connect(func(kind,_id): sounds.append(kind))
	boss.attack_phase = "recover"
	boss.attack_time = 10
	boss.state.inv = 0
	boss.hurt(100)
	game._physics_process(.01)
	assert(game.players.size() == 1 and game.phase == "play" and game.exploration.status == "active")
	var reward: Dictionary = game.Reward.current(game)
	assert(reward.source == "boss" and reward.state == "forming" and reward.item == 4)
	var offsets = game.Reward.scatter_offsets(game.arena,reward.pos,1234,3)
	assert(offsets == game.Reward.scatter_offsets(game.arena,reward.pos,1234,3))
	assert(offsets != game.Reward.scatter_offsets(game.arena,reward.pos,5678,3))
	for i in range(offsets.size()):
		assert(not game.arena.solid(reward.pos+offsets[i],22))
		assert(not game.arena.line_blocked(reward.pos,reward.pos+offsets[i]))
		for j in range(i): assert(offsets[i].distance_to(offsets[j]) > 40)
	var saved_offset: Vector2 = reward.drop_offset
	game.rebuild_chest()
	assert(reward.drop_offset == saved_offset)
	var delay: float = reward.delay
	game.set_pause_reason("menu",true)
	game._physics_process(1)
	assert(reward.delay == delay)
	game.set_pause_reason("menu",false)
	player.state.pos = game.room_data(room).doors[0].position
	assert(not game.try_enter_door())
	for n in range(52): game._physics_process(.1)
	assert(reward.state == "closed" and sounds.count("chest_spawn") == 1 and sounds.count("landing") == 1)
	assert(sounds.count("win") == 0)
	player.state.pos = reward.pos+Vector2(0,48)
	player.sync_visual()
	game.fit_field_camera()
	game.refresh_hud()
	await capture("boss-reward-chest")
	game.door_armed = true
	assert(game.try_chest() and reward.state == "open")
	assert(game.try_chest() and not reward.claimed)
	game._physics_process(.12)
	await capture("boss-reward-opening")
	game._physics_process(.28)
	await capture("boss-reward-open")
	assert(not game.BossFlow.claim(game)) # Still airborne.
	var opening_before: float = game.chest_node.opening
	game.set_pause_reason("menu",true)
	game._physics_process(.5)
	assert(game.chest_node.opening == opening_before)
	game.set_pause_reason("menu",false)
	game._physics_process(.5)
	await capture("boss-reward-landed-item")
	game.set_pause_reason("focus",true)
	assert(not game.BossFlow.claim(game))
	game.set_pause_reason("focus",false)
	var inventory = game.exploration.inventory
	for n in range(8): assert(inventory.store_field_relic(0))
	assert(not game.BossFlow.claim(game) and not reward.claimed and inventory.gold[0] == 0)
	assert(not game.BossFlow.blocks_exit(game)) # No full-reserve soft lock.
	# Restore the test reserve, leaving the equipped starting gun.
	inventory.builds[0].owned = inventory.builds[0].owned.slice(0,1)
	assert(game.BossFlow.claim(game))
	assert(reward.state == "empty" and reward.item == 4 and inventory.gold[0] == 5)
	assert(not game.BossFlow.claim(game) and inventory.gold[0] == 5)
	assert(player.state.max_hp == 4) # Acquisition alone is not equipment or healing.
	assert(game.open_bag())
	var draft = game.bag.draft
	var item = draft.builds[0].owned[-1]
	assert(draft.place(0,item,draft.auto_place(0,item)))
	assert(game.apply_bag_changes() and player.state.max_hp == 5 and player.state.hp == 4)
	game.close_bag()
	player.state.pos = game.room_data(room).doors[0].position
	game.door_armed = true
	assert(game.try_enter_door())
	game._physics_process(.01)
	assert(game.phase == "result" and game.exploration.status == "completed" and sounds.count("win") == 1)
	game.start_exploration(22)
	enter(game,room)
	assert(game.players[1].attack_time == .8 and game.Reward.current(game).is_empty())
	game._physics_process(.81)
	assert(not game.boss_intro())
	# Simultaneous death still wins over boss rewards.
	game.players[0].state.hp = 0
	game.players[1].state.hp = 0
	game._physics_process(.01)
	assert(game.exploration.status == "dead" and game.Reward.current(game).is_empty())
	game.queue_free()
	await process_frame
	print("PASS: startup skip/pause/retry, reward delay/SE, single airborne drop, full reserve, no duplicate, HP equip, explicit exit completion and simultaneous death")
	quit()
