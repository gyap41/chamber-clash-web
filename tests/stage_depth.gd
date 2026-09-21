extends SceneTree
func _initialize() -> void: call_deferred("run")
func capture(name: String) -> void:
	if "--capture" not in OS.get_cmdline_user_args(): return
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://.local/depth-"+name+".png") == OK)
func run() -> void:
	root.size = Vector2i(1120,800)
	var game = load("res://scenes/game/exploration.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.set_pause_reason("focus",false)
	var arena = game.arena
	assert(arena.y_sort_enabled and arena.get_node("Players").y_sort_enabled)
	assert(arena.get_node("StageBackground").y_sort_enabled)
	var north = arena.get_node("Walls/Wall1")
	assert(north.wall_rise == 36 and north.collision_rect() == Rect2(96,80,928,48))
	var side = arena.get_node("Walls/Wall3")
	assert(side.upper_extension == 84 and side.joint_caps.size() == 1)
	assert(side.position.y-side.upper_extension == north.position.y-north.wall_rise)
	assert(arena.get_node("Walls/Wall4").joint_caps.size() == 2)
	assert(arena.get_node("Walls/Wall5").joint_caps.size() == 1)
	assert(side.collision_rect() == Rect2(96,128,32,384))
	var bench = arena.get_node("StageBackground").get_child(1)
	assert(bench.position == bench.definition.position+Vector2(0,bench.definition.visual_rect.end.y))
	var player = game.players[0]
	player.state.pos = Vector2(350,390)
	assert(not arena.solid(player.state.pos,player.radius))
	player.sync_visual()
	assert(player.position.y < bench.position.y)
	await capture("behind-bench")
	player.state.pos = Vector2(350,490)
	assert(not arena.solid(player.state.pos,player.radius))
	player.sync_visual()
	assert(player.position.y > bench.position.y)
	await capture("front-bench")
	player.state.pos = Vector2(438,468)
	assert(not arena.solid(player.state.pos,player.radius))
	player.sync_visual()
	await capture("beside-bench")
	var other = preload("res://data/fields/workshop_annex.tres")
	assert(game.switch_field(other).is_empty())
	assert(not arena.y_sort_enabled and not arena.get_node("Players").y_sort_enabled)
	assert(arena.get_node("Walls").z_index == 0)
	game.queue_free()
	await process_frame
	print("PASS: wall height independent of collision, foot anchors, depth layers, front/back positions, reset on room switch")
	quit()
