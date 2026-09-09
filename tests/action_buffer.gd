extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func mouse(game, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	game._input(event)
	game._unhandled_input(event)
func key(game, code: int, pressed: bool = true, echo: bool = false) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = pressed
	event.echo = echo
	game._input(event)
	game._unhandled_key_input(event)
func run() -> void:
	var game = load("res://scenes/game/main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	preload("res://tests/helpers/battle.gd").start(game)
	var p = game.players[0]
	p.equip_slot(0)
	p.state.shot = 0.0
	p.state.roll = .08
	var clip: int = p.weapon().clip
	mouse(game,true)
	mouse(game,false)
	game._physics_process(.04)
	assert(p.weapon().clip == clip)
	game._physics_process(.04)
	assert(p.weapon().clip == clip-1 and p.buffered_fire == 0)
	game._physics_process(.3)
	assert(p.weapon().clip == clip-1) # released tap fires exactly once
	p.state.roll = .2
	mouse(game,true)
	mouse(game,false)
	game._physics_process(.2)
	assert(p.weapon().clip == clip-1) # early tap is not retained
	p.state.roll = .08
	mouse(game,true)
	game._physics_process(.08)
	game._physics_process(.3)
	assert(p.weapon().clip == clip-3 and p.buffered_fire == 0)
	mouse(game,false)
	# Expire a tap blocked by a longer reload; never replay it when reload finishes.
	p.state.roll = .05
	p.state.reload = .3
	p.state.reload_slot = -1
	var before_reload: int = p.weapon().clip
	mouse(game,true)
	mouse(game,false)
	game._physics_process(.05)
	game._physics_process(.3)
	assert(p.weapon().clip == before_reload and p.buffered_fire == 0)
	p.state.roll = .08
	p.relics = [16]
	key(game,KEY_E)
	key(game,KEY_E,true,true)
	assert(p.state.gun == 0 and game.delayed_shots.is_empty())
	game._physics_process(.08)
	assert(p.state.gun == 1 and game.delayed_shots.size() == 1)
	game._physics_process(.01)
	assert(p.state.gun == 1 and game.delayed_shots.size() == 1)
	# Simultaneous requests prioritize switching; its normal 150ms delay prevents
	# the 100ms fire tap from becoming a shot from either weapon.
	p.state.roll = .08
	var old_clip: int = p.inventory[0].clip
	var new_clip: int = p.inventory[1].clip
	mouse(game,true)
	mouse(game,false)
	game.equip_slot(0,0)
	game._physics_process(.08)
	game._physics_process(.2)
	assert(p.state.gun == 0 and p.inventory[0].clip == old_clip and p.inventory[1].clip == new_clip)
	p.equip_slot(1)
	# UI slot selection shares the same buffer; latest explicit slot wins.
	p.state.roll = .08
	game.equip_slot(0,0)
	game.equip_slot(0,1)
	game._physics_process(.08)
	assert(p.state.gun == 1)
	p.state.roll = .2
	game.equip_slot(0,0)
	game._physics_process(.2)
	assert(p.state.gun == 1)
	# Pause, focus loss, result and new round discard both actions.
	for reason in ["pause","focus","result","reset"]:
		p.state.roll = .08
		mouse(game,true)
		game.equip_slot(0,0)
		assert(p.buffered_fire > 0 and p.buffered_switch > 0)
		match reason:
			"pause": key(game,KEY_ESCAPE)
			"focus": game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
			"result":
				game.remaining = 0.0
				game._physics_process(.001)
			"reset": game.new_match(42)
		assert(p.buffered_fire == 0 and p.buffered_switch == 0 and not game.mouse_fire_held)
		game.paused = false
		game.result = ""
		game.phase = "play"
		game.remaining = 90.0
	var q = game.players[1]
	q.state.roll = .08
	q.state.shot = 0.0
	key(game,KEY_L)
	key(game,KEY_L,false)
	var qclip: int = q.weapon().clip
	game._physics_process(.08)
	assert(q.weapon().clip == qclip-1)
	key(game,KEY_L)
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	assert(not q.keyboard_fire_held and q.buffered_fire == 0)
	print("PASS: 100ms tap/hold/expiry, single switch, UI/latest slot, pause/focus/result/reset, local P2")
	game.queue_free()
	quit()
