extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var game = load("res://scenes/game/main.tscn").instantiate()
	root.add_child(game)
	preload("res://tests/helpers/battle.gd").passive_opponents(game)
	game.set_physics_process(false)
	start_combat(game)
	assert(game.catalog.guns.size() == 38)
	assert(game.catalog.relics.size() == 35) # Includes stackable IDs 18/19
	game.fighters[0].pos = Vector2(60,82)
	game.move_fighter(game.fighters[0],Vector2(-100,-100))
	assert(game.fighters[0].pos == Vector2(60,82))
	game.move_fighter(game.fighters[0],Vector2(20,20))
	assert(game.fighters[0].pos.is_equal_approx(Vector2(80,102)))
	game.fighters[0].pos = Vector2(210,190)
	game.move_fighter(game.fighters[0],Vector2(200,0))
	assert(game.fighters[0].pos.x <= 226)
	start_combat(game)
	game.players[0].weapon().clip = 2
	game.players[0].weapon().reserve = 3
	game.players[0].start_reload()
	game.fighters[0].reload = .01
	game._physics_process(.02)
	assert(game.players[0].weapon().clip == 5 and game.players[0].weapon().reserve == 0)
	game.fighters[1].hp = 0
	game._physics_process(.02)
	assert(game.result == "P1 WINS")
	start_combat(game)
	game.remaining = .01
	game._physics_process(.02)
	assert(game.result == "DRAW")
	await extended(game)
	print("PASS: catalog, bounds, corner escape, collision, finite reload, victory, timeout")
	game.queue_free()
	quit()

func key(game, code: int) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	game._unhandled_key_input(event)
# P1 melee is now a mouse right-click, not a keyboard key (see main.gd's _unhandled_input).
func right_click(game) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_RIGHT
	event.pressed = true
	game._unhandled_input(event)

func extended(game) -> void:
	assert(game.catalog.characters.size() == 8)
	# All four corners: clamp, then escape inward.
	for corner in [Vector2(60,82),Vector2(1060,82),Vector2(60,540),Vector2(1060,540)]:
		var inward := Vector2(1 if corner.x == 60 else -1,1 if corner.y == 82 else -1)
		game.fighters[0].pos = corner
		game.move_fighter(game.fighters[0],-inward*100)
		assert(game.fighters[0].pos == corner)
		game.move_fighter(game.fighters[0],inward*20)
		assert(game.fighters[0].pos.is_equal_approx(corner+inward*20))
	start_combat(game)
	game.fire(0)
	assert(game.shots.size() == 1 and game.players[0].weapon().clip == 15)
	game.fire(0)
	assert(game.shots.size() == 1) # cooldown
	var b = game.shots[0]
	b.state.pos = Vector2(1087,100)
	b.state.velocity = Vector2(420,0)
	b.step(.02,game.arena,game.players[1])
	assert(b.state.life <= 0)
	start_combat(game)
	key(game,KEY_E)
	game._physics_process(.16)
	game.fire(0)
	b = game.shots[0]
	b.state.pos = Vector2(1087,100)
	b.state.velocity = Vector2(420,0)
	b.step(.02,game.arena,game.players[1])
	assert(not b.state.dead and b.state.bounce == 1 and b.state.velocity.x < 0)
	# Thin-wall collision at a large time step.
	b.state.pos = Vector2(210,190)
	b.state.velocity = Vector2(420,0)
	b.step(.2,game.arena,game.players[1])
	assert(b.state.bounce == 0 and b.state.velocity.x < 0)
	start_combat(game)
	key(game,KEY_SPACE)
	game.players[0].hurt(1)
	assert(game.fighters[0].hp == 8 and game.fighters[0].roll > 0)
	game.fire(0)
	assert(game.shots.is_empty())
	game._physics_process(.1)
	assert(game.fighters[0].pos.x > 170)
	start_combat(game)
	game.fighters[0].pos = Vector2(170,100)
	game.fighters[1].pos = Vector2(220,100)
	game.fighters[0].angle = 0.0
	for i in range(4):
		game.fighters[1].shot = 0.0
		game.fire(1)
		game.shots[-1].state.pos = Vector2(200,100)
	right_click(game)
	assert(game.shots.filter(func(shot): return shot.state.dead).size() == 3)
	assert(is_equal_approx(game.fighters[1].hp,7.4))
	assert(game.fighters[0].shot >= .3)
	start_combat(game)
	game.fire(0)
	key(game,KEY_ESCAPE)
	var before: Vector2 = game.shots[0].state.pos
	var clock: float = game.remaining
	game._physics_process(.5)
	key(game,KEY_E)
	assert(game.remaining == clock and game.shots[0].state.pos == before and game.fighters[0].gun == 0)
	key(game,KEY_ESCAPE)
	assert(not game.paused)
	game.fighters[0].hp = 0
	game._physics_process(.01)
	assert(game.result == "P2 WINS")
	key(game,KEY_ENTER)
	assert(game.result == "" and game.shots.is_empty() and game.fighters[0].hp == 8)
	# Editor edits are consumed by the simulation.
	var wall = game.arena.get_node("Walls/Wall1")
	var old_position: Vector2 = wall.position
	wall.position = Vector2(100,100)
	assert(game.arena.solid(Vector2(110,110),4))
	wall.position = old_position
	var spawn = game.arena.get_node("Spawns/P1")
	spawn.position = Vector2(100,200)
	game.players[0].max_hp = 10
	start_combat(game)
	assert(game.fighters[0].pos == spawn.position and game.players[0].position == spawn.position and game.fighters[0].hp == 10)
	print("PASS: scene edits, 4 corners, fire cooldown, normal/bounce walls, dodge, melee cap/damage, pause, restart")

func start_combat(game) -> void:
	game.new_match(31)
	preload("res://tests/helpers/battle.gd").start(game,1)
	for player in game.players:
		player.equip_slot(0)
		player.state.shot = 0.0
