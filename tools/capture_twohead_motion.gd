extends SceneTree
const OUT = "res://docs/archive/2026-09-12/rina-twohead/motion/"
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	root.size = Vector2i(1120,800)
	var game = load("res://scenes/game/main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	preload("res://tests/helpers/battle.gd").passive_opponents(game)
	game.assign_character(0,0)
	preload("res://tests/helpers/battle.gd").start(game,20)
	var p = game.players[0]
	p.state.pos = Vector2(370,320)
	for frame in range(64):
		var axis := Vector2.UP if frame < 32 else Vector2.DOWN
		p.step(.025,axis.angle(),game.players[1],game.arena,false,{"dx":axis.x,"dy":axis.y,"shoot":false,"aim_jitter":0.0})
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		assert(root.get_texture().get_image().save_png(OUT+"%02d.png" % frame) == OK)
	assert(p.state.pos.distance_to(Vector2(370,320)) < .1)
	print("PASS: Actual player.step up/down travel captured, returns to start")
	game.queue_free()
	quit()
