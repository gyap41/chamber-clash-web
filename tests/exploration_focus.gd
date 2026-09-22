extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var game = load("res://scenes/game/exploration.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	var player = game.players[0]
	for cycle in range(3):
		game.mouse_fire_held = true
		game.submit_command("p1",{"dx":1.0})
		game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
		assert(game.paused and not game.mouse_fire_held and game.submitted_commands.is_empty())
		var before: Vector2 = player.state.pos
		game._physics_process(.05)
		assert(player.state.pos == before)
		game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
		assert(not game.paused and not game.mouse_fire_held)
		game.submit_command("p1",{"dx":1.0})
		game._physics_process(.05)
		assert(player.state.pos.x > before.x)
	game.set_pause_reason("menu",true)
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	assert(game.paused and game.pause_reasons.has("menu"))
	game.set_pause_reason("menu",false)
	assert(game.open_bag())
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	assert(game.paused and game.bag != null and game.pause_reasons.has("inventory"))
	game.close_bag()
	assert(not game.paused)
	game.queue_free()
	await process_frame
	print("PASS: focus loss stops, focus return restores movement, clears stale inputs, preserves menu and bag pauses")
	quit()
