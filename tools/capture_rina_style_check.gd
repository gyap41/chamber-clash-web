extends SceneTree
# Rina style check (docs/art/VISUAL_STYLE_GUIDE.md step 0): the current 8-direction rig in
# every direction, idle and running in place, on the exploration floor at the normal camera.
# Saves 1:1 and 3x sheets. Does not modify game assets.
const OUT := "res://docs/art/reviews/rina-style-check-2026-09-26/"
const ROOM := "pillared"
const RINA_POS := Vector2(696,610)
const CELL := Vector2i(96,128)
# Screen angles: 0 = right, PI/2 = down (front view).
const DIRECTIONS := 8
const IDLE_SAMPLES := 2
const RUN_FRAMES := 8
# One run frame is 6/8 of the walk phase; the phase advances 14 per second at 205 px/s.
const RUN_FRAME_DT := 6.0/8.0/14.0
# Views drawn separately by the rig (the left-facing three are mirrors): right, down-right, down, up-right, up.
const ZOOM_DIRECTIONS := [0,1,2,7,6]
const ZOOM_COLUMNS := [0,4,8] # idle, run frame 2, run frame 6 in the 1:1 sheet
var game
var rina

func _initialize() -> void:
	call_deferred("run")

func grab() -> Image:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	image.convert(Image.FORMAT_RGBA8)
	return image

func pose(angle: float, moving: bool, dt: float) -> void:
	rina.state.pos = RINA_POS
	rina.state.angle = angle
	rina.state.dir = Vector2.from_angle(angle) if moving else Vector2.ZERO
	rina.sync_visual()
	rina.advance_visual(dt,moving)

func cell_image(image: Image) -> Image:
	var center: Vector2 = game.arena.get_global_transform_with_canvas()*RINA_POS
	return image.get_region(Rect2i(int(center.x)-CELL.x/2,int(center.y)-CELL.y+56,CELL.x,CELL.y))

func save(image: Image, name: String) -> void:
	assert(image.save_png(OUT+name) == OK)

func run() -> void:
	# Rina is compared in her current 8-direction rig, which the game only enables with --rina-run or V.
	preload("res://scripts/visuals/character_rig8.gd").enabled = true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	root.size = Vector2i(1120,800)
	root.content_scale_size = root.size
	game = load("res://scenes/game/workshop_variants_preview.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	game.start_room = ROOM
	game.start_exploration(1)
	game.set_physics_process(false)
	rina = game.players[0]
	rina.get_node("Identity").hide()
	pose(PI/4,false,.1)
	game.fit_field_camera()
	game.refresh_hud()
	save(await grab(),"in-game.png")
	game.get_node("HUD").visible = false
	var columns := IDLE_SAMPLES+RUN_FRAMES
	var sheet := Image.create(CELL.x*columns,CELL.y*DIRECTIONS,false,Image.FORMAT_RGBA8)
	var cells: Array = []
	for d in range(DIRECTIONS):
		var angle := d*PI/4
		var row: Array = []
		# Settle the direction (hysteresis) and swing parts before sampling.
		for i in range(10): pose(angle,false,.05)
		for i in range(IDLE_SAMPLES):
			pose(angle,false,.6 if i > 0 else .0)
			row.append(cell_image(await grab()))
		for i in range(10): pose(angle,true,RUN_FRAME_DT)
		# Line the run cycle up with frame 0, then sample every frame.
		for i in range(RUN_FRAMES):
			if rina.get_node("Animation").rig_frame == 0: break
			pose(angle,true,RUN_FRAME_DT)
		for i in range(RUN_FRAMES):
			row.append(cell_image(await grab()))
			pose(angle,true,RUN_FRAME_DT)
		for c in range(row.size()):
			sheet.blit_rect(row[c],Rect2i(Vector2i.ZERO,CELL),Vector2i(c*CELL.x,d*CELL.y))
		cells.append(row)
	save(sheet,"sheet-normal.png")
	var zoom := Image.create(CELL.x*3*ZOOM_COLUMNS.size(),CELL.y*3*ZOOM_DIRECTIONS.size(),false,Image.FORMAT_RGBA8)
	for r in range(ZOOM_DIRECTIONS.size()):
		for c in range(ZOOM_COLUMNS.size()):
			var big: Image = cells[ZOOM_DIRECTIONS[r]][ZOOM_COLUMNS[c]].duplicate()
			big.resize(CELL.x*3,CELL.y*3,Image.INTERPOLATE_NEAREST)
			zoom.blit_rect(big,Rect2i(Vector2i.ZERO,big.get_size()),Vector2i(c*CELL.x*3,r*CELL.y*3))
	save(zoom,"sheet-3x.png")
	game.queue_free()
	await process_frame
	print("PASS: rina style check captured")
	quit()
