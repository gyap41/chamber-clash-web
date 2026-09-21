extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func capture(name: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://.local/exploration-"+name+".png") == OK)
func run() -> void:
	root.size = Vector2i(1120,800)
	var title = load("res://scenes/ui/title.tscn").instantiate()
	root.add_child(title)
	await capture("title")
	title.start_story()
	var game = root.get_node("Exploration")
	game.set_physics_process(false)
	await capture("play")
	game.set_pause_reason("menu",true)
	game._physics_process(0)
	await capture("pause")
	game.set_pause_reason("menu",false)
	game.players[0].state.hp = 0
	game._physics_process(.01)
	await capture("result")
	game.queue_free()
	await process_frame
	print("PASS: exploration captures")
	quit()
