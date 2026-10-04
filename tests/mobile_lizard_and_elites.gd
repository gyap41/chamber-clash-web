extends "res://tests/fire_pouch_lizard.gd"
const Registry = preload("res://scripts/catalog/enemy_registry.gd")
const Rig = preload("res://scripts/visuals/elite_machine_visual.gd")
func run() -> void:
	var game = load("res://scenes/game/exploration.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.set_pause_reason("focus",false)
	assert(game.arena.configure_field(field(),1).is_empty())
	var player = game.players[0]
	player.state.pos = Vector2(800,450)
	for id in ["fire_pouch_lizard","ember_lizard","iron_quill"]:
		var actor = load("res://scenes/combat/player.tscn").instantiate()
		actor.set_script(Registry.script_for(id))
		game.arena.get_node("Players").add_child(actor)
		actor.prepare(Vector2(500,450))
		actor.attack_phase = "spit"
		actor.attack_time = 10
		actor.shots_left = int(actor.spec.shots)
		var start: Vector2 = actor.state.pos
		for n in range(20): actor.step(1.0/60,1,player,game.arena)
		if id == "iron_quill": assert(actor.state.pos == start and actor.gait_phase == 0)
		else:
			assert(actor.state.pos.distance_to(start) > 10 and actor.gait_phase > 0)
			var angles: Array = []
			for shot in range(int(actor.spec.shots)):
				actor.shots_left = int(actor.spec.shots)-shot
				angles.append(actor.shot_angle()-actor.attack_angle)
			assert(angles.max() > .15 and angles.min() < -.15)
			assert(preload("res://scripts/visuals/enemy_sheet_visual.gd").frame(actor.enemy_visual_snapshot(),true).row < 4)
			actor.attack_phase = "spit"
			actor.shots_left = 3
			actor.attack_time = .2
			player.state.pos.y += 2
			actor.step(.02,1,player,game.arena)
			assert(actor.attack_angle > (player.state.pos-actor.state.pos).angle(),"Lead covers lateral motion")
			actor.attack_time = .08
			var locked: float = actor.attack_angle
			player.state.pos.y += 5
			actor.step(.02,1,player,game.arena)
			assert(actor.attack_angle == locked,"Final tell stays locked")
		actor.queue_free()
		await process_frame
	for id in ["ash_ram","triple_ring"]:
		var actor = load("res://scenes/combat/player.tscn").instantiate()
		actor.set_script(Registry.script_for(id))
		game.arena.get_node("Players").add_child(actor)
		actor.prepare(Vector2(500,450))
		assert(actor.enemy_visual_snapshot().enemy_id == id)
		for row in range(3):
			for col in range(3):
				var bounds := Rig.region(id == "ash_ram",row,col)
				assert(bounds.size.x > 30 and bounds.size.y > 30)
		actor.hurt(100)
		var remains = get_nodes_in_group("enemy_death_visuals")[-1]
		assert(not remains.organic and remains.snapshot.enemy_id == id)
		actor.queue_free()
		await process_frame
	var firing := {"phase":"spit","remaining":.5,"shot_interval":.5}
	assert(Rig.pose(firing).kick == 1)
	firing.remaining = .3
	assert(Rig.pose(firing).kick == 0)
	game.queue_free()
	await process_frame
	print("PASS: mobile lizards only, gait, spray, lateral lead/final lock, 18 dedicated parts and mechanical deaths")
	quit()
