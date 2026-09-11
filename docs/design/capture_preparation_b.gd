extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	root.size = Vector2i(1120,800)
	var game = load("res://scenes/game/main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.new_match(42)
	var ms = game.match_state
	var prep = game.preparation
	prep.set_process(false)
	ms.stage = 4
	ms.scores = [2,1]
	var gun: String = ms.gun_token(1)
	ms.builds[0] = {"owned":[gun,2,4,0,3],"equipped":[],"positions":{},"mods":{}}
	ms.rewards[0] = [1,7,10]
	ms.remaining[0] = 1
	assert(ms.place(0,gun,Vector2i(0,0)))
	assert(ms.place(0,2,Vector2i(2,0)))
	assert(ms.place(0,4,Vector2i(0,2)))
	prep.refresh()
	prep.show_detail(0)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://docs/design/preparation-b-implemented.png") == OK)
	prep.select_entry(0)
	assert(prep.preview_at(0,Vector2i(3,3)))
	await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://docs/design/preparation-b-preview.png") == OK)
	game.queue_free()
	await process_frame
	print("PASS: B native-size reference captures")
	quit()
