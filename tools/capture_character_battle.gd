extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	root.size=Vector2i(1120,800)
	var game=load("res://scenes/game/main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	preload("res://tests/helpers/battle.gd").passive_opponents(game)
	game.assign_character(0,5)
	game.assign_character(1,7)
	preload("res://tests/helpers/battle.gd").start(game,25)
	var p=game.players[0]
	var q=game.players[1]
	q.inventory.clear()
	q.add_gun(27)
	p.state.pos=Vector2(340,430)
	q.state.pos=Vector2(730,430)
	p.state.angle=0.0
	q.state.angle=PI
	p.sync_visual()
	q.sync_visual()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://docs/archive/2026-09-12/character-integration/battle.png")==OK)
	print("PASS: Luna/Crow game capture with starter weapons")
	quit()
