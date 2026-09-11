extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func press(game, key: int) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.pressed = true
	game._unhandled_key_input(event)
func run() -> void:
	var game = load("res://scenes/game/main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	preload("res://tests/helpers/battle.gd").start(game,15)
	game.supplies.reset()
	var p = game.players[0]
	var cpu = game.players[1]
	var item = game.supplies.put_item("weapon",7,p.state.pos)
	item.age = 1.0
	press(game,KEY_G)
	assert(item.opening_player == -1)
	game.paused = true
	press(game,KEY_F)
	assert(item.opening_player == -1)
	game.paused = false
	press(game,KEY_F)
	assert(item.opening_player == 0)
	game.supplies.step(game.supplies.chest_open_duration)
	assert("gun:7" in game.match_state.builds[0].owned)
	game.supplies.reset()
	# Actual turning and the forward cone, at a clear location above the walls.
	p.state.pos = Vector2(170,100)
	cpu.state.pos = Vector2(400,180)
	game.spawn_shot(0,15,0.0)
	var bullet = game.shots.back()
	bullet.step(.1,game.arena,cpu)
	assert(is_equal_approx(bullet.state.velocity.angle(),.12))
	assert(is_equal_approx(bullet.state.velocity.length(),340.0))
	game.spawn_shot(0,15,PI)
	bullet = game.shots.back()
	bullet.step(.1,game.arena,cpu)
	assert(absf(absf(bullet.state.velocity.angle())-PI) < .001)
	for shot in game.shots:
		shot.get_parent().remove_child(shot)
		shot.queue_free()
	game.shots.clear()
	# Walk real player physics for multiple seconds: edges, wall faces and corners.
	# Keep a tempting chest outside the safe area to exercise retreat/seek hysteresis.
	for start in [Vector2(220,200),Vector2(900,400),Vector2(70,90),Vector2(1050,530),Vector2(280,140),Vector2(840,460),Vector2(560,90),Vector2(560,530)]:
		cpu.reset(start)
		cpu.state.pulses = 0
		game.remaining = 2.0
		p.state.pos = start+Vector2(0,80)
		item = game.supplies.put_item("weapon",9,start)
		var reached := false
		for frame in range(600):
			var decision: Dictionary = game.CpuAI.decide(game,cpu,p,1.0/60.0)
			cpu.step(1.0/60.0,1,p,game.arena,false,decision)
			if Rect2(300,213.1,520,173.8).has_point(cpu.state.pos):
				reached = true
				break
		assert(reached,"CPU failed to escape from %s; ended at %s" % [start,cpu.state.pos])
		game.supplies.reset()
	# Result buttons appear on a round result and final victory, disappear on reset.
	var actions = game.hud.get_node("Root/ResultActions")
	assert(not actions.visible)
	for score in [1,5]:
		game.result = "P1 WIN"
		game.scores[0] = score
		game.hud.refresh(game.players,game.remaining,false,game.result,game.scores,game.phase)
		assert(actions.visible)
		assert(actions.get_node("NextRound").visible == (score < 5))
		assert(actions.get_node("CharacterSelect").visible == (score == 5))
		assert(actions.get_node("Title").visible == (score == 5))
	if "--result-screenshot" in OS.get_cmdline_user_args():
		await process_frame
		await process_frame
		root.get_texture().get_image().save_png("res://.local/logs/result-actions.png")
	game.players[1].is_cpu = true
	game.mouse_fire_held = true
	actions.get_node("CharacterSelect").pressed.emit()
	assert(game.get_parent() == null and not game.mouse_fire_held)
	var select = root.get_child(root.get_child_count()-1)
	assert(select.cpu_mode and select.picked == [-1,-1])
	select.select_character(0)
	var fresh = root.get_child(root.get_child_count()-1)
	fresh.set_physics_process(false)
	assert(fresh.scores == [0,0] and fresh.phase == "prepare")
	assert(not fresh.hud.get_node("Root/ResultActions").visible)
	fresh.result = "P2 WIN"
	fresh.scores[1] = 5
	fresh.hud.get_node("Root/ResultActions/Title").pressed.emit()
	assert(fresh.get_parent() == null)
	var title = root.get_child(root.get_child_count()-1)
	assert(title.has_node("Panel/Content/Start"))
	title.queue_free()
	print("PASS: F chest input, weaker star homing, eight CPU edge escapes, result navigation and fresh match")
	quit()


