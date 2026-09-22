extends "res://tests/exploration_rooms.gd"
const Definition = preload("res://scripts/world/field_definition.gd")

func field(blocked: bool = false):
	var result = Definition.new()
	result.field_id = "ranged-test"
	result.field_rect = Rect2(0,0,1600,1000)
	result.fighter_bounds = Rect2(14,14,1572,972)
	result.projectile_bounds = Rect2(0,0,1600,1000)
	result.spawns = PackedVector2Array([Vector2(700,450)])
	if blocked: result.walls.append(Rect2(600,350,20,200))
	return result

func reset_pair(game, enemy) -> void:
	game.clear_field_objects()
	assert(game.arena.configure_field(field(),1).is_empty())
	enemy.prepare(Vector2(500,450))
	game.players[0].state.pos = Vector2(700,450)
	game.players[0].state.hp = 8
	game.players[0].state.inv = 0

func run() -> void:
	root.size = Vector2i(1120,800)
	var game = load("res://scenes/game/exploration.tscn").instantiate()
	game.random_floor = true
	root.add_child(game)
	game.set_physics_process(false)
	game.start_exploration(22)
	game.set_pause_reason("focus",false)
	var ids: Array = game.floor_data.rooms.keys().filter(func(id): return game.floor_data.rooms[id].role == "normal")
	for index in range(2):
		game.Encounter.retire(game)
		var id: String = ids[index]
		game.exploration.enter_room(id,game.room_data(id).field.field_id)
		game.switch_field(game.room_data(id).field)
		game.Encounter.begin(game)
		assert(game.players[1].spec.id == "workshop_sentry")
		assert(game.players[2].spec.id == ("workshop_sentry" if index == 0 else "fire_pouch_lizard"))
	var lizard = game.players[2]
	var player = game.players[0]
	# Capture in the actual mixed room, before replacing geometry with the isolated fixture.
	var position_found := false
	for y in range(200,900,32):
		for x in range(200,1200,32):
			var point := Vector2(x,y)
			if not game.arena.fighter_bounds.has_point(point+Vector2(220,0)): continue
			if Navigation.segment_clear(game.arena,point,point+Vector2(220,0)):
				lizard.state.pos = point
				player.state.pos = point+Vector2(220,0)
				position_found = true
				break
		if position_found: break
	assert(position_found)
	lizard.attack_phase = "windup"
	lizard.attack_time = .15
	lizard.attack_angle = 0
	lizard.shots_left = 2
	lizard.sync_visual()
	player.sync_visual()
	game.fit_field_camera()
	game.refresh_hud()
	await capture("lizard-windup")
	lizard.step(.16,2,player,game.arena)
	game.combat._step_projectiles(.3)
	game.refresh_hud()
	await capture("lizard-shot")
	reset_pair(game,lizard)
	lizard.step(1.0,2,player,game.arena)
	assert(game.shots.is_empty() and lizard.attack_phase == "grace")
	lizard.step(.21,2,player,game.arena)
	assert(lizard.attack_phase == "windup" and game.shots.is_empty())
	var remaining: float = lizard.attack_time
	game.set_pause_reason("menu",true)
	game._physics_process(1.0)
	assert(lizard.attack_time == remaining and game.shots.is_empty())
	game.set_pause_reason("menu",false)
	player.state.pos += Vector2(0,80)
	lizard.step(.81,2,player,game.arena)
	assert(game.shots.size() == 1 and is_zero_approx(game.shots[0].state.velocity.y))
	lizard.step(.23,2,player,game.arena)
	assert(game.shots.size() == 2 and is_zero_approx(game.shots[1].state.velocity.y))
	lizard.step(.23,2,player,game.arena)
	assert(lizard.attack_phase == "recover")
	lizard.step(.5,2,player,game.arena)
	assert(game.shots.size() == 2)
	game.combat._step_projectiles(1.2)
	assert(player.state.hp == 8) # sideways movement avoids the locked stream
	# Ordinary collision, damage, hostile roster and pulse cancellation.
	reset_pair(game,lizard)
	game.players[1].state.pos = Vector2(600,450)
	var ally_hp: float = game.players[1].state.hp
	lizard.step(1.21,2,player,game.arena)
	lizard.step(.81,2,player,game.arena)
	assert(game.shots[0].gun_id == -1 and not game.shots[0].state.comet)
	game.combat._step_projectiles(1.0)
	assert(is_equal_approx(player.state.hp,7.45) and game.players[1].state.hp == ally_hp)
	lizard.step(.23,2,player,game.arena)
	assert(game.shots.size() == 1)
	assert(game.combat.use_pulse(0) and game.shots.is_empty())
	# Dodge/pulse invulnerability uses the same ordinary projectile damage gate.
	reset_pair(game,lizard)
	lizard.step(1.21,2,player,game.arena)
	lizard.step(.81,2,player,game.arena)
	player.state.inv = 1.0
	game.combat._step_projectiles(1.0)
	assert(player.state.hp == 8)
	# Existing walls stop emitted seeds, and prevent starting a fresh windup.
	reset_pair(game,lizard)
	lizard.step(1.21,2,player,game.arena)
	lizard.step(.81,2,player,game.arena)
	assert(game.arena.configure_field(field(true),1).is_empty())
	game.combat._step_projectiles(1.0)
	assert(player.state.hp == 8 and game.shots.is_empty())
	lizard.attack_phase = "recover"
	lizard.attack_time = 0
	lizard.step(.01,2,player,game.arena)
	assert(lizard.attack_phase != "windup")
	lizard.state.pos = Vector2(580,450)
	lizard.attack_phase = "windup"
	lizard.attack_angle = 0
	lizard.attack_time = .01
	lizard.shots_left = 2
	lizard.step(.02,2,player,game.arena)
	assert(game.shots.is_empty() and lizard.attack_phase == "recover")
	# Just outside the playable camera area, even though still in shooting range.
	reset_pair(game,lizard)
	player.state.pos = Vector2(800,700)
	lizard.state.pos = Vector2(800,395)
	lizard.step(1.21,2,player,game.arena)
	assert(lizard.attack_phase != "windup" and game.shots.is_empty())
	lizard.state.pos = Vector2(800,500)
	lizard.step(.01,2,player,game.arena)
	assert(lizard.attack_phase == "windup" and game.shots.is_empty())
	lizard.state.pos = Vector2(800,395)
	lizard.step(.81,2,player,game.arena)
	assert(lizard.attack_phase == "recover" and game.shots.is_empty())
	# Death cancels queued spits; re-entry retains the selected composition.
	reset_pair(game,lizard)
	lizard.step(1.21,2,player,game.arena)
	lizard.step(.81,2,player,game.arena)
	lizard.state.hp = 0
	lizard.step(1.0,2,player,game.arena)
	assert(game.shots.size() == 1)
	var chosen: Array = game.exploration.room_state(ids[1]).enemy_ids.duplicate()
	game.Encounter.retire(game)
	assert(game.shots.is_empty())
	game.Encounter.begin(game)
	assert(game.exploration.room_state(ids[1]).enemy_ids == chosen and game.players[2].spec.id == "fire_pouch_lizard")
	game.start_exploration(22)
	assert(game.exploration.room_states.values().all(func(value): return not value.has("enemy_ids")))
	game.queue_free()
	await process_frame
	print("PASS: lizard introduction/mixed roster, locked two-shot burst, recovery, pause, walls, damage, pulse, offscreen cancellation, death and retry")
	quit()
