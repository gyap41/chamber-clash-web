extends "res://tests/fire_pouch_lizard.gd"
const Sheet = preload("res://scripts/visuals/enemy_sheet_visual.gd")

func run() -> void:
	var game = load("res://scenes/game/exploration.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	# Four dedicated contact/passing frames and separately drawn left view.
	for organic in [false,true]:
		var view := {"alive":true,"angle":0.0,"phase":"chase","remaining":0.0,
			"windup":.8,"recovery":1.4,"reach":62.0,"hp_ratio":1.0,"gait":0.0,"motion":1.0}
		for index in range(4):
			view.gait = index*TAU/4+.01
			assert(Sheet.frame(view,organic).row == index)
		view.angle = PI
		assert(Sheet.frame(view,organic).column == 3 and not Sheet.frame(view,organic).mirror)
		view.death_progress = .5
		assert(Sheet.frame(view,organic).row == 7)
	var enemy = load("res://scenes/combat/player.tscn").instantiate()
	enemy.set_script(load("res://scripts/combat/exploration_enemy.gd"))
	game.arena.get_node("Players").add_child(enemy)
	enemy.prepare(Vector2(300,300))
	enemy.attack_phase = "chase"
	enemy.state.pos += Vector2(10,0)
	enemy.advance_visual(.1,true)
	assert(enemy.gait_phase > 0 and enemy.motion_weight > 0)
	var before: float = enemy.gait_phase
	enemy.advance_visual(.1,true)
	assert(enemy.gait_phase == before and enemy.motion_weight == 0)
	enemy.prepare(Vector2(300,300))
	assert(enemy.gait_phase == 0 and enemy.motion_weight == 0)
	assert(enemy.hurt(.2))
	assert(enemy.enemy_visual_snapshot().hit > 0 and enemy.state.hp > 0)
	enemy.state.inv = 0
	assert(enemy.hurt(99))
	var remains = get_nodes_in_group("enemy_death_visuals")[-1]
	assert(remains.snapshot.alive == false)
	enemy.queue_free()
	await process_frame
	assert(is_instance_valid(remains))
	game.set_pause_reason("menu",true)
	game._physics_process(.2)
	assert(remains.elapsed == 0)
	game.set_pause_reason("menu",false)
	game.set_pause_reason("focus",false)
	game._physics_process(.1)
	assert(remains.elapsed > 0)
	remains.elapsed = .08
	assert(remains.particles().any(func(p): return p.spark))
	remains.organic = true
	remains.elapsed = .5
	assert(not remains.particles().is_empty())
	assert(remains.particles().all(func(p): return not p.spark))
	game.clear_enemy_deaths()
	await process_frame
	assert(not is_instance_valid(remains))
	var expiry = preload("res://scripts/visuals/enemy_death.gd").new()
	expiry.snapshot = {"alive":false}
	root.add_child(expiry)
	expiry.step(expiry.DURATION)
	await process_frame
	assert(not is_instance_valid(expiry))
	game.queue_free()
	await process_frame
	print("PASS: dedicated walk/death frames, separate left view, distance clock, blocked movement and reset")
	quit()
