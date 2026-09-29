extends SceneTree
# Hand-authored room trial captures (docs/art/production/authored-rooms): for each room, the whole room fitted
# to the screen and one normal-scale (camera 1.2) view at its set piece, Rina for scale, HUD hidden.
# Run: Godot --path . --script res://tools/capture_authored_rooms.gd --quit-after 4000
const OUT := "res://docs/art/production/authored-rooms/views/"
const Authored = preload("res://scripts/world/authored_rooms.gd")
# Where Rina stands for the normal-scale view (the camera follows her).
const FOCUS := {"collapsed_gallery":Vector2(416,420),"casting_line":Vector2(640,500),
	"camp_remains":Vector2(600,420),"root_hall":Vector2(640,480),
	"twin_halls":Vector2(850,450),"loading_bay":Vector2(680,490),
	"storage_cells":Vector2(720,450),"overlook":Vector2(720,600),
	"beast_nest":Vector2(550,400),"archive":Vector2(570,430),"antechamber":Vector2(490,435),
	"cistern":Vector2(385,470),"vault":Vector2(620,430),"chapel":Vector2(560,475),"secret_room":Vector2(940,460)}

func _initialize() -> void:
	call_deferred("run")

func grab() -> Image:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	image.convert(Image.FORMAT_RGBA8)
	return image

func run() -> void:
	preload("res://scripts/visuals/character_rig8.gd").enabled = true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	root.size = Vector2i(1120,800)
	root.content_scale_size = root.size
	var only := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--only="): only = argument.trim_prefix("--only=")
	assert(only.is_empty() or only in Authored.ORDER,"Unknown capture room")
	for i in range(Authored.ORDER.size()):
		var id: String = Authored.ORDER[i]
		if not only.is_empty() and only != id: continue
		var game = load("res://scenes/game/authored_rooms_preview.tscn").instantiate()
		game.start_room = id
		root.add_child(game)
		await process_frame
		game.set_physics_process(false)
		game.start_room = id
		game.start_exploration(1)
		game.set_physics_process(false)
		game.get_node("HUD").visible = false
		var rina = game.players[0]
		rina.state.pos = FOCUS.get(id,Vector2(420,450))
		var reach = preload("res://scripts/world/room_reachability.gd")
		if not reach.clear_point(game.arena.runtime_definition,rina.state.pos):
			rina.state.pos = game.arena.runtime_definition.spawns[0]
		rina.state.angle = PI/4
		rina.sync_visual()
		for step in range(6): rina.advance_visual(.05,false)
		rina.get_node("Identity").hide()
		game.fit_field_camera()
		var detail: Image = await grab()
		assert(detail.save_png(ProjectSettings.globalize_path(OUT+"%02d-%s-detail.png" % [i+1,id])) == OK)
		if id == "courtyard":
			game.get_node("HUD").visible = true
			var ui: Image = await grab()
			assert(ui.save_png(ProjectSettings.globalize_path(OUT+"room-picker.png")) == OK)
			game.get_node("HUD").visible = false
		var camera: Camera2D = game.arena.get_node("CombatCamera")
		var bounds: Rect2 = game.arena.field_rect
		var zoom := minf(1120.0/bounds.size.x,800.0/bounds.size.y)
		camera.zoom = Vector2.ONE*zoom
		camera.position = bounds.get_center()-Vector2(560,400)/zoom
		camera.force_update_scroll()
		var overview: Image = await grab()
		assert(overview.save_png(ProjectSettings.globalize_path(OUT+"%02d-%s-overview.png" % [i+1,id])) == OK)
		if id == "collapsed_gallery":
			assert(await capture_gallery_checks(game,rina),"Gallery walkthrough or depth capture failed")
		game.queue_free()
		await process_frame
	var sheet := Image.create(2240,400*ceili(Authored.ORDER.size()/4.0),false,Image.FORMAT_RGBA8)
	for i in range(Authored.ORDER.size()):
		var small := Image.load_from_file(ProjectSettings.globalize_path(OUT+"%02d-%s-overview.png" % [i+1,Authored.ORDER[i]]))
		assert(small != null,"Capture all rooms once before using --only")
		small.resize(560,400,Image.INTERPOLATE_BILINEAR)
		sheet.blit_rect(small,Rect2i(0,0,560,400),Vector2i((i%4)*560,(i/4)*400))
	assert(sheet.save_png(ProjectSettings.globalize_path(OUT+"sheet.png")) == OK)
	print("PASS: authored rooms captured")
	quit()

func capture_gallery_checks(game, rina) -> bool:
	# Scripted traversal through the real arena collision solver, not a recording of manual input.
	var routes := [
		[Vector2(170,400),Vector2(390,400),Vector2(390,220),Vector2(650,220),Vector2(650,315),Vector2(700,335),Vector2(740,400),Vector2(950,400)],
		[Vector2(170,400),Vector2(390,450),Vector2(400,506),Vector2(720,506),Vector2(950,400)]
	]
	for route in routes:
		for backwards in [false,true]:
			var points: Array = route.duplicate()
			if backwards: points.reverse()
			rina.state.pos = points[0]
			for target in points.slice(1):
				var steps := 0
				while rina.state.pos.distance_to(target) > .1:
					var previous: Vector2 = rina.state.pos
					var delta: Vector2 = previous.direction_to(target)*minf(4,previous.distance_to(target))
					game.arena.move_fighter(rina.state,delta,rina.radius)
					assert(rina.state.pos.distance_to(previous+delta) < .1,"Gallery route hit an obstacle")
					steps += 1
					assert(steps < 1000,"Gallery route stalled")
	assert(game.arena.line_blocked(Vector2(170,400),Vector2(950,400)),"Collapse should interrupt the straight shot")
	# Pose checks are deliberately outside collision, on either side of a surviving wall or column.
	var poses := {"wall-behind":Vector2(413,532),"wall-front":Vector2(413,612),"column-behind":Vector2(820,240)}
	for label in poses:
		rina.state.pos = poses[label]
		assert(preload("res://scripts/world/room_reachability.gd").clear_point(game.arena.runtime_definition,rina.state.pos),"Capture pose intersects collision")
		rina.state.angle = PI/4
		rina.sync_visual()
		game.fit_field_camera()
		var shot: Image = await grab()
		assert(shot.save_png(ProjectSettings.globalize_path(OUT+"01-gallery-"+label+".png")) == OK)
	print("PASS: gallery north/south routes walked both ways with arena collision; direct shot blocked; depth poses captured")
	return true
