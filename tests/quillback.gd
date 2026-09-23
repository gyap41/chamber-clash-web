extends "res://tests/fire_pouch_lizard.gd"

func run() -> void:
	root.size = Vector2i(1120,800)
	var game = load("res://scenes/game/exploration.tscn").instantiate()
	game.random_floor = true
	root.add_child(game)
	game.set_physics_process(false)
	game.start_exploration(22)
	game.set_pause_reason("focus",false)
	var ids: Array = game.floor_data.rooms.keys().filter(func(id): return game.floor_data.rooms[id].role == "normal")
	var actor
	for id in ids:
		game.Encounter.retire(game)
		game.exploration.enter_room(id,game.room_data(id).field.field_id)
		game.switch_field(game.room_data(id).field)
		game.Encounter.begin(game)
		var matches: Array = game.players.filter(func(p): return p.get("spec") != null and p.spec.id == "quillback")
		if not matches.is_empty():
			actor = matches[0]
			break
	assert(actor != null)
	var index: int = game.players.find(actor)
	for delta in [Vector2(100,0),Vector2(-100,0),Vector2(0,-100),Vector2(0,100)]:
		if not game.arena.solid(actor.state.pos+delta,20):
			game.players[0].state.pos = actor.state.pos+delta
			break
	game.players[0].sync_visual()
	game.fit_field_camera()
	game.refresh_hud()
	await capture("quillback-room")
	reset_pair(game,actor)
	var player = game.players[0]
	actor.step(1.31,index,player,game.arena)
	assert(actor.attack_phase == "windup")
	var locked: float = actor.attack_angle
	game.set_pause_reason("menu",true)
	var remaining: float = actor.attack_time
	game._physics_process(.2)
	assert(actor.attack_time == remaining and game.shots.is_empty())
	game.set_pause_reason("menu",false)
	player.state.pos.y += 30
	actor.step(.5,index,player,game.arena)
	assert(actor.attack_angle == locked and game.shots.is_empty())
	actor.sync_visual()
	player.sync_visual()
	game.fit_field_camera()
	game.refresh_hud()
	await capture("quillback-windup")
	actor.step(.46,index,player,game.arena)
	assert(game.shots.size() == 5 and actor.attack_phase == "spit")
	for n in range(5):
		assert(is_equal_approx(game.shots[n].state.velocity.angle(),locked+(n-2)*.22))
		assert(game.shots[n].gun_id == actor.Spec.QUILL_ID)
	actor.step(.26,index,player,game.arena)
	assert(actor.attack_phase == "recover" and game.shots.size() == 5)
	game.combat._step_projectiles(.1)
	await capture("quillback-fan")
	reset_pair(game,actor)
	actor.attack_angle = 0
	actor.spit(index,game.arena)
	var hp: float = player.state.hp
	for frame in range(50): game.combat._step_projectiles(.016)
	assert(player.state.hp < hp)
	reset_pair(game,actor)
	actor.step(1.31,index,player,game.arena)
	player.state.pos = Vector2(1500,900)
	actor.step(1.0,index,player,game.arena)
	assert(game.shots.is_empty() and actor.attack_phase == "recover")
	reset_pair(game,actor)
	assert(game.arena.configure_field(field(true),1).is_empty())
	actor.step(1.31,index,player,game.arena)
	assert(actor.attack_phase != "windup" and game.shots.is_empty())
	reset_pair(game,actor)
	actor.state.inv = 0
	actor.hurt(100)
	actor.step(3,index,player,game.arena)
	assert(game.shots.is_empty())
	var remains = get_nodes_in_group("enemy_death_visuals")
	assert(not remains.is_empty() and remains[-1].snapshot.enemy_id == "quillback" and remains[-1].organic)
	game.Encounter.retire(game)
	assert(game.shots.is_empty() and game.players.size() == 1)
	game.queue_free()
	await process_frame
	print("PASS: quillback roster, locked five-shot fan, recovery, offscreen/wall/death cancellation and organic death visual")
	quit()
