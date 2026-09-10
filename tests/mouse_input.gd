extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func mouse(at: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = at
	event.global_position = at
	event.button_index = MOUSE_BUTTON_LEFT
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()
func mouse_right(at: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = at
	event.global_position = at
	event.button_index = MOUSE_BUTTON_RIGHT
	event.button_mask = MOUSE_BUTTON_MASK_RIGHT if pressed else 0
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()
func mouse_wheel(index: int, at: Vector2 = Vector2(100,120)) -> void:
	var event := InputEventMouseButton.new()
	event.position = at
	event.global_position = at
	event.button_index = index
	event.pressed = true
	Input.parse_input_event(event)
	Input.flush_buffered_events()
func mouse_move(at: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = at
	event.global_position = at
	Input.parse_input_event(event)
	Input.flush_buffered_events()
func run() -> void:
	root.size = Vector2i(1120,800)
	var game = load("res://scenes/game/main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	await process_frame
	await process_frame
	mouse(Vector2(100,120),true)
	assert(not game.mouse_fire_held)
	mouse(Vector2(100,120),false)
	preload("res://tests/helpers/battle.gd").start(game,1)
	var p = game.players[0]
	p.equip_slot(0)
	p.state.shot = 0.0
	game._physics_process(0.0)
	await process_frame
	mouse(Vector2(100,120),true)
	assert(game.mouse_fire_held)
	game._physics_process(.01)
	assert(p.weapon().clip == 11 and game.shots.size() == 1)
	game._physics_process(.1)
	assert(p.weapon().clip == 11)
	game._physics_process(.2)
	assert(p.weapon().clip == 10)
	mouse(Vector2(100,120),false)
	game._physics_process(.3)
	assert(not game.mouse_fire_held and p.weapon().clip == 10)
	# A real GUI slot click equips but cannot start continuous firing.
	var slot: Button = game.hud.slots[0][1]
	var center := slot.get_global_rect().get_center()
	mouse(center,true)
	mouse(center,false)
	assert(p.state.gun == 1 and not game.mouse_fire_held)
	game._physics_process(.3)
	assert(p.weapon().clip == p.definition().mag)
	mouse(Vector2(100,120),true)
	var pause_event := InputEventKey.new()
	pause_event.pressed = true
	pause_event.keycode = KEY_ESCAPE
	game._unhandled_key_input(pause_event)
	assert(game.paused and not game.mouse_fire_held)
	mouse(Vector2(100,120),true)
	assert(not game.mouse_fire_held)
	game._unhandled_key_input(pause_event)
	assert(not game.mouse_fire_held)
	mouse(Vector2(100,120),false)
	mouse(Vector2(100,120),true)
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	assert(not game.mouse_fire_held)
	mouse(Vector2(100,120),false)
	game.paused = false
	# P1 now aims freely at the mouse cursor (2026-09-08) instead of always facing the enemy —
	# put the enemy somewhere that would give a very different angle if aim were still
	# enemy-locked, so this only passes if the mouse position is actually driving p.angle.
	p.state.pos = Vector2(400,400)
	game.players[1].state.pos = Vector2(900,100)
	mouse_move(Vector2(400,500)) # due south of p, not toward the enemy at all
	game._physics_process(.01)
	var expected_angle: float = (Vector2(400,500)-Vector2(400,400)).angle()
	assert(is_equal_approx(wrapf(p.state.angle-expected_angle,-PI,PI),0.0))
	# P1's melee is a right-click (2026-09-08), not the V key.
	p.inventory[p.state.gun].clip = 5
	p.state.melee = 0.0
	p.state.reload = 0.0
	p.state.roll = 0.0
	game.players[1].state.hp = game.players[1].state.max_hp
	game.players[1].state.pos = p.state.pos+Vector2(0,30) # within melee_range(64), dead ahead of the mouse-driven facing above
	mouse_right(Vector2(400,500),true)
	assert(p.state.melee > 0.0 and game.players[1].state.hp < game.players[1].state.max_hp)
	mouse_right(Vector2(400,500),false)
	# マウスホイールでのP1武器切替（2026-09-10追加）：Eキー/1〜4キーの既存経路とは別の追加
	# 入力経路。巡回方向がホイールアップ／ダウンで前後になっていることと、既存のE/1〜4
	# キー経路と同じガード（非ポーズ・非決着）に従うことを検証する。
	assert(p.add_gun(16) and p.add_gun(19) and p.inventory.size() == 4)
	p.equip_slot(0)
	assert(p.state.gun == 0)
	mouse_wheel(MOUSE_BUTTON_WHEEL_UP)
	assert(p.state.gun == 1)
	mouse_wheel(MOUSE_BUTTON_WHEEL_UP)
	assert(p.state.gun == 2)
	mouse_wheel(MOUSE_BUTTON_WHEEL_UP)
	assert(p.state.gun == 3)
	mouse_wheel(MOUSE_BUTTON_WHEEL_UP)
	assert(p.state.gun == 0) # 末尾から先頭へ巡回
	mouse_wheel(MOUSE_BUTTON_WHEEL_DOWN)
	assert(p.state.gun == 3) # 先頭から末尾へ逆巡回
	mouse_wheel(MOUSE_BUTTON_WHEEL_DOWN)
	assert(p.state.gun == 2)
	# P2（完全キーボード操作）はホイール入力の影響を受けない。
	var q_gun_before: int = game.players[1].state.gun
	mouse_wheel(MOUSE_BUTTON_WHEEL_UP)
	mouse_wheel(MOUSE_BUTTON_WHEEL_DOWN)
	assert(game.players[1].state.gun == q_gun_before)
	# ポーズ中・決着後はEキーの巡回切替と同じくホイールも無視される。
	var gun_before_guard: int = p.state.gun
	game.paused = true
	mouse_wheel(MOUSE_BUTTON_WHEEL_UP)
	assert(p.state.gun == gun_before_guard)
	game.paused = false
	game.result = "P1 WINS"
	mouse_wheel(MOUSE_BUTTON_WHEEL_UP)
	assert(p.state.gun == gun_before_guard)
	game.result = ""
	print("PASS: left click hold/release, fire interval, real GUI slot click, preparation, pause, focus loss, mouse-driven aim, right-click melee, mouse wheel weapon switch")
	game.queue_free()
	quit()
