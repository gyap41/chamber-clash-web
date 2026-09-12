extends SceneTree
const OUT = "res://docs/archive/2026-09-12/rina-dive/"
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
	p.state.pos = Vector2(350,450)
	p.state.dir = Vector2.RIGHT
	p.state.angle = 0
	p.try_dodge()
	for frame in range(48):
		p.step(.01,0,game.players[1],game.arena,false,{"dx":0.0,"dy":0.0,"angle":0.0,"shoot":false})
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		assert(root.get_texture().get_image().save_png(OUT+"%02d.png" % frame) == OK)
	print("PASS: Continuous Rina dive capture")
	game.queue_free()
	quit()
