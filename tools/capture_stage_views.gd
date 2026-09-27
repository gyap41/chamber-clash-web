extends SceneTree
# Stage material check (docs/art/production/ashen-foundry-v2): the room-shape gallery with the current
# ashen foundry theme, camera placed on walls, outer/inner corners and doorways, Rina for scale, HUD hidden.
# Saves 1:1 captures and one contact sheet. Does not modify game assets.
# Run: Godot --path . --script res://tools/capture_stage_views.gd --quit-after 3000
const OUT := "res://docs/art/production/ashen-foundry-v2/views/"
# [room shape, Rina position]: the camera follows Rina.
const SHOTS := [
	["elbow",Vector2(260,230)],     # outer top-left corner, north and west walls
	["elbow",Vector2(760,470)],     # inner corner of the upper-right cutout
	["cross",Vector2(560,420)],     # stepped inner corners
	["standard",Vector2(170,300)],  # west doorway
	["west_annex",Vector2(700,820)],# south wall and pillar
	["pillared",Vector2(700,520)],  # open floor with furniture (overgrown: roots, moss)
	["pillared",Vector2(420,250)],  # overgrown: root from the north wall, moss, nest
]
# Generated floor (seed 22) rooms by role: entrance (storage, tea table) and treasure room (rug), plus the
# gallery's standard room with its doors forced to the sealed state.
const FLOOR_ROLES := ["start","treasure"]
const SEED := 22

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
	var images: Array = []
	for i in range(SHOTS.size()):
		var game = load("res://scenes/game/workshop_variants_preview.tscn").instantiate()
		root.add_child(game)
		await process_frame
		game.set_physics_process(false)
		game.start_room = SHOTS[i][0]
		game.start_exploration(1)
		game.set_physics_process(false)
		game.get_node("HUD").visible = false
		var rina = game.players[0]
		rina.state.pos = SHOTS[i][1]
		rina.state.angle = PI/4
		rina.sync_visual()
		for step in range(6): rina.advance_visual(.05,false)
		rina.get_node("Identity").hide()
		game.fit_field_camera()
		var image: Image = await grab()
		assert(image.save_png(ProjectSettings.globalize_path(OUT+"%02d-%s.png" % [i+1,SHOTS[i][0]])) == OK)
		images.append(image)
		game.queue_free()
		await process_frame
	for role in FLOOR_ROLES:
		var game = load("res://scenes/game/exploration.tscn").instantiate()
		game.random_floor = true
		root.add_child(game)
		await process_frame
		game.set_physics_process(false)
		game.start_exploration(SEED)
		game.set_physics_process(false)
		var id: String = game.floor_data.rooms.keys().filter(func(r): return game.floor_data.rooms[r].role == role)[0]
		game.Encounter.retire(game)
		game.exploration.enter_room(id,game.room_data(id).field.field_id)
		game.switch_field(game.room_data(id).field)
		game.get_node("HUD").visible = false
		var rina = game.players[0]
		rina.state.pos = game.arena.field_rect.get_center()+Vector2(0,60)
		rina.sync_visual()
		rina.get_node("Identity").hide()
		game.fit_field_camera()
		var image: Image = await grab()
		assert(image.save_png(ProjectSettings.globalize_path(OUT+"%02d-floor-%s.png" % [images.size()+1,role])) == OK)
		images.append(image)
		game.queue_free()
		await process_frame
	var sealed = load("res://scenes/game/workshop_variants_preview.tscn").instantiate()
	root.add_child(sealed)
	await process_frame
	sealed.set_physics_process(false)
	sealed.start_room = "standard"
	sealed.start_exploration(1)
	sealed.set_physics_process(false)
	sealed.get_node("HUD").visible = false
	for door in sealed.doors: door.set_locked(true)
	sealed.players[0].state.pos = Vector2(200,300)
	sealed.players[0].sync_visual()
	sealed.players[0].get_node("Identity").hide()
	sealed.fit_field_camera()
	var sealed_image: Image = await grab()
	assert(sealed_image.save_png(ProjectSettings.globalize_path(OUT+"%02d-sealed-door.png" % [images.size()+1])) == OK)
	images.append(sealed_image)
	sealed.queue_free()
	await process_frame
	var sheet := Image.create(1120,400*int(ceil(images.size()/2.0)),false,Image.FORMAT_RGBA8)
	for i in range(images.size()):
		var small: Image = images[i].duplicate()
		small.resize(560,400,Image.INTERPOLATE_BILINEAR)
		sheet.blit_rect(small,Rect2i(0,0,560,400),Vector2i((i%2)*560,(i/2)*400))
	assert(sheet.save_png(ProjectSettings.globalize_path(OUT+"sheet.png")) == OK)
	print("PASS: stage views captured")
	quit()
