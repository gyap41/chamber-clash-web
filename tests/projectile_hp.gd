extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var game = load("res://scenes/game/main.tscn").instantiate()
	root.add_child(game)
	preload("res://tests/helpers/battle.gd").passive_opponents(game)
	game.set_physics_process(false)
	game.phase = "play"
	var p = game.players[0]
	var q = game.players[1]
	for id in range(38):
		game.spawn_shot(0,id,0,{"pos":Vector2(400,100)})
		var shot = game.shots.back()
		var art = shot.get_node("Art")
		assert(art.visible and not shot.get_node("Visual").visible)
		assert(art.texture != null and art.centered and art.offset == Vector2.ZERO)
		assert(art.scale.x>0 and art.scale.y>0)
		var bounds = preload("res://scripts/catalog/weapon_visual_catalog.gd").vec(art.profile.bullet_size)
		assert((art.texture.get_size()*art.scale).x<=bounds.x+.01 and (art.texture.get_size()*art.scale).y<=bounds.y+.01)
		var radius: float = shot.radius
		shot.state.velocity = Vector2.LEFT*100
		shot.step(0.0,game.arena,q)
		assert(is_equal_approx(absf(art.rotation),PI) and shot.radius == radius)
	game.spawn_shot(0,17,0,{"parcel":true})
	assert(game.shots.back().get_node("Art").variant == "parcel")
	game.spawn_shot(0,16,0,{"shard":true})
	assert(game.shots.back().get_node("Art").variant == "derived")
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
	p.add_relic(4) # 9 HP character + 1 maximum HP.
	p.state.hp = 7.5
	game._physics_process(0.0)
	var bar = game.hud.get_node("Root/HP1")
	assert(bar.opacities.size() == 10)
	assert(bar.opacities[6] == 1.0 and is_equal_approx(bar.opacities[7],.6) and is_equal_approx(bar.opacities[8],.2))
	assert(bar.mouse_filter == Control.MOUSE_FILTER_IGNORE)
	p.state.hp = 0
	game._physics_process(0.0)
	assert(bar.opacities.all(func(value): return is_equal_approx(value,.2)))
	game.reset_round()
	assert(bar.opacities.size() == 9 and bar.opacities.all(func(value): return value == 1.0))
	print("PASS: all weapon projectile aspect/center/direction/variants/pause/reset and HP fractional/max/relic/reset display")
	game.queue_free()
	quit()
