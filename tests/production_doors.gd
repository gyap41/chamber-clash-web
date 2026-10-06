extends SceneTree
var game
var visited := {}
var transitions := 0
func _initialize(): call_deferred("run")
func clear_room():
	if game.boss_intro(): game.BossFlow.finish_intro(game)
	for enemy in game.players.slice(1):
		enemy.state.inv = 0
		enemy.hurt(1000)
	game._physics_process(.016)
func wait_for_gate_open():
	game.refresh_hud()
	for gate in game.doors:
		assert(not gate.locked)
		gate.step(gate.OPEN_SECONDS)
		assert(gate.passage_ready())
func cross(door):
	wait_for_gate_open()
	game.players[0].state.pos = door.position
	game.players[0].sync_visual()
	game.door_armed = true
	assert(game.try_enter_door())
	assert(game.exploration.room_id == door.target_room)
	assert(not game.arena.solid(game.players[0].state.pos,game.players[0].radius))
	transitions += 1
func visit():
	var id = game.exploration.room_id
	visited[id] = true
	clear_room()
	var reward = game.Reward.current(game)
	if not reward.is_empty():
		game.players[0].state.pos = reward.pos
		game._physics_process(1)
		game.door_armed = true
		assert(game.try_chest())
		assert(reward.state == "open")
	for door in game.room_data(id).doors:
		if visited.has(door.target_room) or game.floor_data.rooms[door.target_room].role == "boss": continue
		cross(door)
		visit()
		cross(game.door_data(door.target_room,door.target_door))
		assert(game.players.size() == 1)
func run():
	game = load("res://scenes/game/exploration.tscn").instantiate()
	game.random_floor = true
	game.authored_campaign = true
	root.add_child(game)
	game.set_physics_process(false)
	game.start_exploration(27)
	game.set_pause_reason("focus",false)
	visit()
	assert(visited.size() == game.floor_data.rooms.size()-1)
	var boss_id = game.floor_data.rooms.keys().filter(func(id): return game.floor_data.rooms[id].role == "boss")[0]
	var back = game.room_data(boss_id).doors[0]
	# Already-cleared antechamber; enter boss through its real door.
	game.Encounter.retire(game)
	game.switch_field(game.room_data(back.target_room).field.duplicate(true))
	game.exploration.enter_room(back.target_room,game.floor_data.rooms[back.target_room].template_id)
	game.rebuild_doors()
	cross(game.door_data(back.target_room,back.target_door))
	clear_room()
	for i in range(52): game._physics_process(.1)
	var reward = game.Reward.current(game)
	assert(reward.source == "boss" and reward.state == "closed")
	game.players[0].state.pos = reward.pos
	game.door_armed = true
	assert(game.try_chest())
	game._physics_process(1)
	assert(game.BossFlow.claim(game))
	wait_for_gate_open()
	game.players[0].state.pos = back.position
	game.door_armed = true
	assert(game.try_enter_door())
	game._physics_process(.01)
	assert(game.exploration.status == "completed")
	print("PASS production doors: ",transitions," crossings, treasure opening, persistence, boss claim and exit")
	game.queue_free()
	await process_frame
	quit()
