extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	assert(game.catalog.guns.size() == 20)
	assert(game.catalog.relics.size() == 12)
	game.fighters[0].pos = Vector2(60,82)
	game.move_fighter(game.fighters[0],Vector2(-100,-100))
	assert(game.fighters[0].pos == Vector2(60,82))
	game.move_fighter(game.fighters[0],Vector2(20,20))
	assert(game.fighters[0].pos.is_equal_approx(Vector2(80,102)))
	game.fighters[0].pos = Vector2(210,190)
	game.move_fighter(game.fighters[0],Vector2(200,0))
	assert(game.fighters[0].pos.x <= 226)
	game.reset_round()
	game.fighters[0].clip = 2
	game.fighters[0].reserve = 3
	game.fighters[0].reload = .01
	game._physics_process(.02)
	assert(game.fighters[0].clip == 5 and game.fighters[0].reserve == 0)
	game.fighters[1].hp = 0
	game._physics_process(.02)
	assert(game.result == "P1 WINS")
	game.reset_round()
	game.remaining = .01
	game._physics_process(.02)
	assert(game.result == "DRAW")
	print("PASS: catalog, bounds, corner escape, collision, finite reload, victory, timeout")
	game.queue_free()
	quit()
