extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var game = load("res://scenes/game/main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.phase = "play"
	var p = game.players[0]
	var q = game.players[1]
	for id in [16,17,18,19]:
		game.spawn_shot(0,id,0,{"pos":Vector2(400,100),"parcel":id == 17})
		var shot = game.shots.back()
		var art = shot.get_node("Art")
		assert(art.visible and not shot.get_node("Visual").visible)
		assert(art.row == id-16 and art.animation_frame == 0)
		var radius: float = shot.radius
		for frame in range(4):
			shot.state.age = frame/12.0
			shot.step(0.0,game.arena,q)
			assert(art.animation_frame == frame)
			assert(is_equal_approx(art.texture.get_width()*art.scale.x,art.WIDTHS[id-16]))
			assert(is_equal_approx(art.offset.x*art.scale.x,-art.WIDTHS[id-16]*art.ANCHORS[id-16]))
			assert(shot.radius == radius)
		shot.state.age = 4.0/12.0
		shot.state.velocity = Vector2.LEFT*100
		shot.step(0.0,game.arena,q)
		assert(art.animation_frame == 0 and is_equal_approx(absf(art.rotation),PI))
	game.spawn_shot(0,17,0)
	assert(not game.shots.back().get_node("Art").visible)
	game.spawn_shot(0,16,0,{"shard":true})
	assert(not game.shots.back().get_node("Art").visible)
	game.spawn_shot(0,0,0)
	assert(game.shots.back().get_node("Visual").visible)
	game.paused = true
	var age: float = game.shots[0].state.age
	game._physics_process(.1)
	assert(game.shots[0].state.age == age)
	game.paused = false
	game.result = "DRAW"
	game._physics_process(.1)
	assert(game.shots[0].state.age == age)
	game.reset_round()
	assert(game.shots.is_empty())
	p.set_character(7)
	p.add_relic(4) # 9 HP character + 2 maximum HP.
	p.state.hp = 7.5
	game._physics_process(0.0)
	var bar = game.hud.get_node("Root/HP1")
	assert(bar.opacities.size() == 11)
	assert(bar.opacities[6] == 1.0 and is_equal_approx(bar.opacities[7],.6) and is_equal_approx(bar.opacities[8],.2))
	assert(bar.mouse_filter == Control.MOUSE_FILTER_IGNORE)
	p.state.hp = 0
	game._physics_process(0.0)
	assert(bar.opacities.all(func(value): return is_equal_approx(value,.2)))
	game.reset_round()
	assert(bar.opacities.size() == 9 and bar.opacities.all(func(value): return value == 1.0))
	print("PASS: projectile four-row/frame/loop/anchor/width/direction/fallback/pause/reset and HP fractional/max/relic/reset display")
	game.queue_free()
	quit()
