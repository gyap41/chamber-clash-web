extends SceneTree
## Static art review only: real room renderer and Rina; no enemy gameplay replacement.
const OUT := "res://docs/art/production/enemy-field-concepts/"
const SOURCE := "res://assets/generated/enemy-field-concepts/"
const IDS := ["root-runner-v1", "mineral-boar-v1", "ring-guard-v1"]
const WIDTHS := [48.0, 88.0, 84.0]
const REACH = preload("res://scripts/world/room_reachability.gd")

func _initialize() -> void:
	call_deferred("run")

func visible_bounds(raw: Image) -> Rect2i:
	# Ignore near-transparent generation residue when measuring the subject; preserve raw pixels.
	var low := raw.get_size()
	var high := Vector2i.ZERO
	for y in range(raw.get_height()):
		for x in range(raw.get_width()):
			if raw.get_pixel(x,y).a > .1:
				low = low.min(Vector2i(x,y))
				high = high.max(Vector2i(x+1,y+1))
	return Rect2i(low,high-low)

func run() -> void:
	var beetle_v3 := "--beetle-v3" in OS.get_cmdline_user_args()
	var beetle_comparison := beetle_v3 or "--beetle-comparison" in OS.get_cmdline_user_args()
	var ids: Array = ["root-runner-v1","root-runner-v2"] if beetle_comparison else IDS
	if beetle_v3: ids = ["root-runner-v2","root-runner-v3"]
	var widths: Array = [48.0,48.0] if beetle_comparison else WIDTHS
	preload("res://scripts/visuals/character_rig8.gd").enabled = true
	root.size = Vector2i(1120,800)
	root.content_scale_size = root.size
	for room_id in ["cistern", "root_hall", "colonnade"]:
		var game = load("res://scenes/game/authored_rooms_preview.tscn").instantiate()
		game.start_room = room_id
		root.add_child(game)
		await process_frame
		game.set_physics_process(false)
		game.start_room = room_id
		game.start_exploration(1)
		game.set_physics_process(false)
		game.get_node("HUD").hide()
		var field = game.arena.runtime_definition
		# Search a clear, horizontal comparison strip, retaining the room's actual geometry.
		var origin := Vector2.ZERO
		for y in range(420,681,20):
			for x in range(280,741,20):
				var valid := true
				for offset in [0,110,240,380]:
					for check in [Vector2.ZERO,Vector2(-40,-25),Vector2(40,25)]:
						if not REACH.clear_point(field,Vector2(x+offset,y)+check): valid = false
				if valid:
					origin = Vector2(x,y)
					break
			if origin != Vector2.ZERO: break
		assert(origin != Vector2.ZERO,"No clear comparison strip in "+room_id)
		var rina = game.players[0]
		rina.state.pos = origin
		rina.state.angle = PI/4
		rina.sync_visual()
		for n in range(6): rina.advance_visual(.05,false)
		rina.get_node("Identity").hide()
		for i in range(ids.size()):
			var raw := Image.load_from_file(ProjectSettings.globalize_path(SOURCE+ids[i]+".png"))
			assert(raw != null and raw.detect_alpha() != Image.ALPHA_NONE,"Transparent source required")
			var used := visible_bounds(raw)
			print(ids[i]," dimensions ",raw.get_size()," alpha bounds ",used)
			var sprite := Sprite2D.new()
			sprite.texture = ImageTexture.create_from_image(raw)
			sprite.region_enabled = true
			sprite.region_rect = Rect2(used)
			sprite.scale = Vector2.ONE*widths[i]/used.size.x
			sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
			# Place the support polygon near the feet, not at the image centre.
			sprite.offset = Vector2(0,-used.size.y*.30)
			sprite.position = origin+Vector2([110,240,380][i],0)
			var shadow := Polygon2D.new()
			var points := PackedVector2Array()
			for n in range(24):
				points.append(Vector2(cos(n*TAU/24)*widths[i]*.35,sin(n*TAU/24)*widths[i]*.13))
			shadow.polygon = points
			shadow.color = Color(0,0,0,.22)
			shadow.position = sprite.position
			game.arena.get_node("Players").add_child(shadow)
			game.arena.get_node("Players").add_child(sprite)
		game.fit_field_camera()
		var camera: Camera2D = game.arena.get_node("CombatCamera")
		camera.position = origin+Vector2(190,0)-Vector2(560,400)/camera.zoom
		camera.force_update_scroll()
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		var shot := root.get_texture().get_image()
		var suffix := "-beetle-v2.png" if beetle_comparison else "-normal.png"
		if beetle_v3: suffix = "-beetle-v3.png"
		assert(shot.save_png(ProjectSettings.globalize_path(OUT+room_id+suffix)) == OK)
		print("CAPTURE ",room_id," at ",origin," zoom ",camera.zoom)
		game.queue_free()
		await process_frame
	print("PASS: three actual-room static comparisons captured")
	quit()
