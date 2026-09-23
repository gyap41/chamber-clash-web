extends "res://tests/exploration_treasure_supplies.gd"

func run() -> void:
	root.size = Vector2i(1120,800)
	var game = load("res://scenes/game/exploration.tscn").instantiate()
	game.random_floor = true
	root.add_child(game)
	game.set_physics_process(false)
	game.start_exploration(22)
	game.set_pause_reason("focus",false)
	enter(game,game.floor_data.rooms.keys().filter(func(id): return game.floor_data.rooms[id].role == "boss")[0])
	var boss = game.players[1]
	var player = game.players[0]
	var sounds: Array = []
	game.sound.played.connect(func(kind,_id): sounds.append(kind))
	boss.state.pos = Vector2(1000,600)
	player.state.pos = Vector2(1300,600)
	boss.attack_phase = "windup"
	boss.move_name = "cannon"
	boss.attack_time = .8
	boss.attack_angle = 0
	player.state.pos = Vector2(1300,650)
	boss.step(.1,1,player,game.arena)
	assert(boss.attack_angle > 0)
	boss.attack_time = .24
	var locked: float = boss.attack_angle
	player.state.pos = Vector2(1300,550)
	boss.step(.1,1,player,game.arena)
	assert(boss.attack_angle == locked)
	boss.step(.15,1,player,game.arena)
	boss.step(.01,1,player,game.arena)
	assert(game.shots.size() == 1 and boss.attack_phase == "recover")
	assert(game.shots[0].damage == 2 and game.shots[0].radius == 14)
	assert(is_equal_approx(game.shots[0].state.velocity.length(),900))
	assert(sounds.count("boss_cannon") == 1)
	boss.sync_visual()
	player.sync_visual()
	game.fit_field_camera()
	game.refresh_hud()
	await capture("boss-cannon-fire")
	game.shots[0].step(.16,game.arena,[])
	await capture("boss-cannon-flight")
	game.clear_field_objects()
	# Direct contact must resolve once, even with no invulnerability protection.
	player.state.pos = Vector2(1120,600)
	player.state.hp = 4
	player.state.inv = 0
	boss.fire_cannon(1,game.arena,0,true)
	var shot = game.shots[0]
	shot.step(.15,game.arena,[player])
	assert(shot.state.life <= 0 and player.state.hp == 4)
	game.combat._step_projectiles(0)
	assert(player.state.hp == 2 and game.shots.is_empty())
	player.state.inv = 0
	game.combat._step_projectiles(.1)
	assert(player.state.hp == 2)
	assert(game.combat_visuals.custom_effects.size() == 1)
	assert(sounds.count("boss_heavy_impact") == 1)
	var effect = game.combat_visuals.custom_effects[0]
	game.set_pause_reason("menu",true)
	game._physics_process(.2)
	assert(effect.age == 0)
	game.set_pause_reason("menu",false)
	boss.sync_visual()
	player.sync_visual()
	game.fit_field_camera()
	game.refresh_hud()
	game.combat_visuals.step(.19)
	await capture("boss-cannon-impact")
	game.combat_visuals.step(.65)
	assert(game.combat_visuals.custom_effects.is_empty())
	# Dodged direct impact never applies a delayed second blast.
	player.state.hp = 4
	player.state.inv = 10
	boss.fire_cannon(1,game.arena,0,true)
	game.combat._step_projectiles(.15)
	assert(player.state.hp == 4 and game.shots.is_empty())
	player.state.inv = 0
	game.combat._step_projectiles(.2)
	assert(player.state.hp == 4)
	# Pulse/removal is not an impact; lifetime expiry is one impact.
	var effects: int = game.combat_visuals.custom_effects.size()
	boss.fire_cannon(1,game.arena,PI,true)
	game.shots[0].state.dead = true
	game.combat._step_projectiles(.01)
	assert(game.combat_visuals.custom_effects.size() == effects)
	boss.fire_cannon(1,game.arena,PI,false)
	game.shots[0].state.life = 0
	game.combat._step_projectiles(0)
	assert(game.combat_visuals.custom_effects.size() == effects+1)
	game.clear_field_objects()
	game.combat_visuals.clear()
	# A wall stops the shell; its blast cannot damage through that wall.
	var wall: Vector2 = boss.state.pos
	for x in range(60,1800,4):
		wall = boss.state.pos+Vector2(x,0)
		if game.arena.solid(wall,1): break
	assert(game.arena.solid(wall,1))
	player.state.pos = wall+Vector2(20,0)
	player.state.hp = 4
	player.state.inv = 0
	boss.fire_cannon(1,game.arena,0,true)
	game.shots[0].state.pos = wall-Vector2(25,0)
	game.combat._step_projectiles(.1)
	assert(game.shots.is_empty() and player.state.hp == 4)
	game.combat_visuals.clear()
	# Normal salvos change angle without tracking; all origins are outside the hull.
	player.state.pos = Vector2(1300,600)
	boss.attack_angle = 0
	boss.salvo_index = 0
	boss.move_name = "salvo"
	var salvo_sounds: int = sounds.count("boss_salvo")
	boss.fire_salvo(1,game.arena)
	var first: float = game.shots[0].state.velocity.angle()
	boss.fire_salvo(1,game.arena)
	assert(game.shots.size() == 24)
	assert(sounds.count("boss_salvo") == salvo_sounds+2)
	assert(is_equal_approx(game.shots[12].state.velocity.angle()-first,TAU/24))
	for bullet in game.shots:
		assert(bullet.damage == 1 and not game.arena.solid(bullet.state.pos,bullet.radius))
		bullet.step(.22,game.arena,[])
	boss.sync_visual()
	player.sync_visual()
	game.fit_field_camera()
	await capture("boss-cannon-salvo")
	game.clear_field_objects()
	# Enraged main cannon re-aims, locks and emits exactly two heavy shells.
	boss.second_phase = true
	boss.attack_phase = "windup"
	boss.move_name = "cannon"
	boss.attack_time = 0
	boss.step(.01,1,player,game.arena)
	boss.step(.01,1,player,game.arena)
	assert(boss.emissions_left == 1 and game.shots.size() == 1)
	player.state.pos = Vector2(1300,700)
	boss.step(.3,1,player,game.arena)
	assert(boss.attack_angle > 0)
	boss.step(.31,1,player,game.arena)
	locked = boss.attack_angle
	player.state.pos = Vector2(1300,500)
	boss.step(.1,1,player,game.arena)
	assert(boss.attack_angle == locked)
	boss.step(.15,1,player,game.arena)
	assert(game.shots.size() == 2 and boss.attack_phase == "recover")
	game.queue_free()
	await process_frame
	print("PASS: cannon tracking/lock, normal/enraged counts, direct/blast once, dodge, explicit removal, expiry, effect pause/cleanup and staggered salvo")
	quit()
