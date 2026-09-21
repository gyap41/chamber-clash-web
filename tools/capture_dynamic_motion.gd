extends SceneTree
# Capture presentation at the normal viewport size with a controlled trajectory.
const OUT = "res://docs/art/reviews/dynamic-motion-2026-09-21/"
const RAW = "res://.local/dynamic-motion-frames/"
func _initialize() -> void: call_deferred("run")
func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	DirAccess.make_dir_recursive_absolute(RAW)
	root.size = Vector2i(1120,800)
	root.content_scale_size = root.size
	var game = load("res://scenes/game/main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	preload("res://tests/helpers/battle.gd").passive_opponents(game)
	game.assign_character(0,0)
	game.assign_character(1,7)
	preload("res://tests/helpers/battle.gd").start(game,20)
	for frame in range(150):
		var time := frame/30.0
		var moving := time >= 1.3 and time < 3.8
		for i in range(2):
			var actor = game.players[i]
			actor.state.pos = Vector2(350+i*380,430)
			if moving: actor.state.pos.x += sin((time-1.3)*2.0)*85
			actor.state.angle = 0.0 if i == 0 else PI
			actor.state.dir = Vector2.RIGHT if cos((time-1.3)*2.0) >= 0 else Vector2.LEFT
			actor.update_weapon_art()
			actor.advance_visual(1.0/30,moving)
			actor.sync_visual()
		game.hud.refresh(game.players,game.remaining,game.paused,game.result,game.scores,game.phase)
		await process_frame
		await RenderingServer.frame_post_draw
		assert(root.get_texture().get_image().save_png(RAW+"%03d.png" % frame) == OK)
		if frame == 60: root.get_texture().get_image().save_png(OUT+"battle.png")
	game.free()
	print("PASS: normal-size battle render / idle, movement, stop / 150 frames")
	quit()
