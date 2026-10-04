extends "res://tests/fire_pouch_lizard.gd"

func run() -> void:
	var game = load("res://scenes/game/exploration.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.set_pause_reason("focus",false)
	assert(game.arena.configure_field(field(),1).is_empty())
	var player = game.players[0]
	var enemy = load("res://scenes/combat/player.tscn").instantiate()
	enemy.set_script(load("res://scripts/combat/exploration_enemy.gd"))
	game.arena.get_node("Players").add_child(enemy)
	for hz in [30,60,120]:
		for spec in [enemy.Spec.SENTRY,enemy.Spec.RUNNER]:
			enemy.spec = spec
			for dodge in [false,true]:
				enemy.attack_phase = "chase"
				enemy.prepare(Vector2(500,450))
				enemy.attack_time = 0
				player.reset(Vector2(500+spec.range-9,450))
				var hp: float = player.state.hp
				enemy.step(0,1,player,game.arena)
				assert(enemy.attack_phase == "windup")
				if dodge:
					player.state.dir = Vector2.DOWN
					player.try_dodge()
				for frame in range(ceili(spec.windup*hz)+1):
					var command := {"dx":0.0 if dodge else 1.0,"dy":1.0 if dodge else 0.0,"angle":0.0,"shoot":false}
					player.step(1.0/hz,0,enemy,game.arena,false,command)
					enemy.step(1.0/hz,1,player,game.arena)
				assert(player.state.hp == hp if dodge else player.state.hp < hp)
				assert(enemy.attack_phase == "recover")
				assert(not game.arena.solid(enemy.state.pos,enemy.radius))
	# Test the actual exploration starter (ID20), not the duel sidearm (ID0).
	player.exploration_starter = true
	var starter: Dictionary = player.resolved_definition(20)
	assert(is_equal_approx(starter.damage,.55))
	var expected := [8,6,7,5]
	var specs := [enemy.Spec.SENTRY,enemy.Spec.LIZARD,enemy.Spec.QUILLBACK,enemy.Spec.RUNNER]
	for index in range(specs.size()):
		enemy.spec = specs[index]
		enemy.prepare(Vector2(500,450))
		var count := 0
		while enemy.state.hp > 0 and count < 20:
			enemy.state.inv = 0
			assert(enemy.hurt(starter.damage,count,false,{},player))
			count += 1
		assert(count == expected[index])
		print("initial pistol: %s = %d hits, %.2fs after first impact" % [enemy.spec.name,count,(count-1)*starter.rate])
	enemy.queue_free()
	game.queue_free()
	await process_frame
	print("PASS: 30/60/120Hz backpedal pressure, sideways dodge counterplay, recovery, initial sidearm hit counts")
	quit()
