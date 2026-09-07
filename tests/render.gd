extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var path := OS.get_environment("CHAMBER_SCREENSHOT")
	if not path.is_empty():
		var error := root.get_texture().get_image().save_png(path)
		assert(error == OK)
	print("PASS: native Compatibility frame rendered")
	quit()
