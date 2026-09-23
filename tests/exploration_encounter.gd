extends "res://tests/exploration_rooms.gd"
var visited := {}
var checked_combat := false
var normal_count := 0

func tick(game, dt: float) -> void:
	game.submit_command("p1",preload("res://scripts/combat/combat_command.gd").idle())
	game._physics_process(dt)

func check_attack(game) -> void:
	var player = game.players[0]
	var enemy = game.players[1]
	var saved: Vector2 = player.state.pos
	var direction := Vector2.ZERO
	for axis in [Vector2.RIGHT,Vector2.DOWN,Vector2.LEFT,Vector2.UP]:
		if Navigation.segment_clear(game.arena,enemy.state.pos,enemy.state.pos+axis*40): direction = axis; break
	assert(direction != Vector2.ZERO)
	player.state.pos = enemy.state.pos+direction*40
	player.state.inv = 0.0
	var hp: float = player.state.hp
	enemy.step(.5,1,player,game.arena)
	assert(enemy.attack_phase == "grace" and player.state.hp == hp)
	enemy.step(.51,1,player,game.arena)
	assert(enemy.attack_phase == "windup" and player.state.hp == hp)
	game.set_pause_reason("menu",true)
	var remaining: float = enemy.attack_time
	var paused_view: Dictionary = enemy.enemy_visual_snapshot()
	game._physics_process(.5)
	assert(enemy.attack_time == remaining and player.state.hp == hp)
	assert(enemy.enemy_visual_snapshot() == paused_view)
	game.set_pause_reason("menu",false)
	player.sync_visual()
	game.fit_field_camera()
	game.refresh_hud()
	# Observe the raised tool after the windup has started, without changing hit timing.
	enemy.step(.30,1,player,game.arena)
	assert(player.state.hp == hp and enemy.attack_phase == "windup")
	await capture("enemy-windup")
	var locked_angle: float = enemy.enemy_visual_snapshot().angle
	player.state.pos = enemy.state.pos-direction*40
	enemy.step(.20,1,player,game.arena)
	assert(is_equal_approx(enemy.enemy_visual_snapshot().angle,locked_angle))
	assert(player.state.hp == hp)
	player.state.pos = enemy.state.pos+direction*40
	enemy.step(.16,1,player,game.arena)
	assert(is_equal_approx(player.state.hp,hp-1.2) and enemy.attack_phase == "recover")
	game.refresh_hud()
	await capture("enemy-strike")
	var damaged: float = player.state.hp
	enemy.step(.5,1,player,game.arena)
	assert(player.state.hp == damaged)
	await capture("enemy-recover")
	# Leaving the locked attack direction evades the hit.
	enemy.attack_phase = "windup"
	enemy.attack_time = .01
	enemy.attack_angle = direction.angle()+PI
	player.state.inv = 0
	enemy.step(.02,1,player,game.arena)
	assert(player.state.hp == damaged)
	# The same tell cannot hit through actual room masonry.
	var wall: Rect2 = game.arena.runtime_definition.walls[0]
	var original: Vector2 = enemy.state.pos
	enemy.state.pos = wall.position+Vector2(24,-10)
	player.state.pos = wall.position+Vector2(24,10)
	enemy.attack_phase = "windup"
	enemy.attack_time = .01
	enemy.attack_angle = PI/2
	enemy.step(.02,1,player,game.arena)
	assert(player.state.hp == damaged)
	enemy.state.pos = original
	player.state.pos = saved
	player.sync_visual()
	# Route around actual furniture, with collision-safe movement on every tick.
	var checked_route := false
	for prop in game.arena.runtime_definition.placements:
		if prop.collision == Rect2(): continue
		var rect := Rect2(prop.position+prop.collision.position,prop.collision.size)
		var left := Vector2(rect.position.x-35,rect.get_center().y)
		var right := Vector2(rect.end.x+35,rect.get_center().y)
		if game.arena.solid(left,18) or game.arena.solid(right,18): continue
		enemy.state.pos = left
		player.state.pos = right
		enemy.attack_phase = "chase"
		enemy.attack_time = 0
		enemy.route_time = 0
		for frame in range(120):
			enemy.step(1.0/60,1,player,game.arena)
			assert(not game.arena.solid(enemy.state.pos,enemy.radius))
		assert(enemy.state.pos.distance_to(left) > 30)
		checked_route = true
		break
	assert(checked_route)
	enemy.state.pos = original
	enemy.sync_visual()
	player.state.pos = saved
	player.sync_visual()
	game.fit_field_camera()
	# Common projectile collision damages the enemy; player melee also uses the roster.
	game.spawn_shot(0,0,0,{"pos":enemy.state.pos,"speed":0.0,"damage":.4,"life":1.0})
	game.combat._step_projectiles(.016)
	assert(enemy.state.hp < enemy.state.max_hp)
	player.state.pos = enemy.state.pos+direction*40
	player.state.angle = (-direction).angle()
	player.state.melee = 0
	enemy.state.inv = 0
	var enemy_hp: float = enemy.state.hp
	game.apply_command(0,{"melee":true})
	assert(enemy.state.hp < enemy_hp)
	player.state.pos = saved
	player.sync_visual()

func visit(game, id: String) -> void:
	visited[id] = true
	var normal: bool = game.floor_data.rooms[id].role == "normal"
	if normal:
		normal_count += 1
		assert(game.players.size() == game.exploration.room_state(id).enemy_ids.size()+1 and game.roster.participants.size() == game.players.size())
		assert(game.exploration.encounter_status == "active")
		for index in [1,2]:
			var enemy = game.players[index]
			assert(not enemy.is_cpu and enemy.inventory.is_empty())
			assert(enemy.participant_id.begins_with(id+"/"))
			assert(not game.arena.solid(enemy.state.pos,enemy.radius))
			assert(enemy.state.pos.distance_to(game.players[0].state.pos) >= 260)
		var saved: Vector2 = game.players[0].state.pos
		game.players[0].state.pos = game.room_data(id).doors[0].position
		game.door_armed = true
		game.refresh_hud()
		assert(not game.try_enter_door() and game.doors.all(func(door): return door.locked and not door.available))
		game.players[0].state.pos = saved
		if not checked_combat:
			await check_attack(game)
			checked_combat = true
		# Old owner references must disappear before the next room can reuse slots.
		game.spawn_shot(1,0,0,{"speed":0.0,"life":10.0})
		game.spawn_well(game.players[1].state.pos,1)
		game.delayed_shots.append({"owner":1,"gun":0,"angle":0.0,"delay":100.0})
		for enemy in game.players.slice(1): enemy.state.inv = 0; enemy.hurt(100)
		tick(game,.016)
		assert(game.exploration.encounter_status == "cleared" and game.exploration.status == "active")
		assert(game.players.size() == 1 and game.roster.participants.size() == 1 and game.fighters.size() == 1)
		assert(game.shots.is_empty() and game.wells.is_empty() and game.delayed_shots.is_empty())
		assert(game.result.is_empty() and game.doors.all(func(door): return not door.locked))
		assert("攻略済み" in game.hud.get_node("Root/Status").text)
		if normal_count == 1: await capture("enemy-cleared")
	else:
		assert(game.players.size() == 1 and game.exploration.encounter_status == "none")
	for door in game.room_data(id).doors:
		if visited.has(door.target_room) or game.floor_data.rooms[door.target_room].role == "boss": continue
		var before := snapshot(game.players[0],game.exploration.inventory)
		game.players[0].state.pos = door.position
		key(game,false); key(game,true); key(game,false)
		assert(game.exploration.room_id == door.target_room)
		assert(snapshot(game.players[0],game.exploration.inventory) == before)
		await visit(game,door.target_room)
		var back: Dictionary = game.door_data(door.target_room,door.target_door)
		game.players[0].state.pos = back.position
		key(game,false); key(game,true); key(game,false)
		assert(game.exploration.room_id == id and game.players.size() == 1)
		assert(game.exploration.encounter_status == ("cleared" if normal else "none"))

func run() -> void:
	root.size = Vector2i(1120,800)
	var game = load("res://scenes/game/exploration.tscn").instantiate()
	game.random_floor = true
	root.add_child(game)
	game.set_physics_process(false)
	game.start_exploration(22)
	await process_frame
	game.set_pause_reason("focus",false)
	await visit(game,game.start_room)
	assert(checked_combat and normal_count == 6 and visited.size() == 10)
	# Retry during combat and death both retire actors without duplicated player signals.
	var normal_id: String = game.floor_data.rooms.keys().filter(func(id): return game.floor_data.rooms[id].role == "normal")[0]
	game.exploration.enter_room(normal_id,game.room_data(normal_id).field.field_id)
	game.exploration.encounter_status = "none"
	game.switch_field(game.room_data(normal_id).field)
	game.Encounter.begin(game)
	assert(game.players.size() >= 4)
	game.spawn_shot(1,0,0,{"speed":0.0,"life":10.0})
	game.start_exploration(22)
	assert(game.players.size() == 1 and game.shots.is_empty())
	assert(game.players[0].delayed_shot_requested.get_connections().size() == 1)
	game.exploration.enter_room(normal_id,game.room_data(normal_id).field.field_id)
	game.switch_field(game.room_data(normal_id).field)
	game.Encounter.begin(game)
	game.players[0].state.hp = 0
	for enemy in game.players.slice(1): enemy.state.hp = 0
	tick(game,.016)
	assert(game.exploration.status == "dead" and game.exploration.encounter_status != "cleared")
	game.start_exploration(22)
	assert(game.players.size() == 1 and game.exploration.status == "active")
	assert(game.exploration.room_states.size() == 1 and game.players[0].state.hp == game.players[0].state.max_hp)
	game.queue_free()
	await process_frame
	print("PASS: encounter lifecycle, six rooms, tells, damage, pause, walls, projectile/melee, owner retirement, revisits and death/retry")
	quit()
