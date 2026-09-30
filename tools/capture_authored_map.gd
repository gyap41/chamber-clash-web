extends SceneTree
const OUT := "res://docs/art/production/authored-rooms/views/"
var game
func _initialize() -> void:
	call_deferred("run")
func grab(name: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var im: Image = root.get_texture().get_image()
	assert(im.save_png(ProjectSettings.globalize_path(OUT+name+".png")) == OK)
func pose(point: Vector2) -> void:
	game.players[0].state.pos = point
	game.players[0].sync_visual()
	game.fit_field_camera()
func run() -> void:
	preload("res://scripts/visuals/character_rig8.gd").enabled = true
	root.size = Vector2i(1120,800)
	root.content_scale_size = root.size
	game = load("res://scenes/game/authored_map_preview.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	game.players[0].get_node("Identity").hide()
	game.start_exploration(27)
	for id in game.room_catalog: game.exploration.visited_rooms[id] = true
	game.open_map()
	await grab("random-map-seed27")
	game.close_map()
	# Version 4: one tree-shaped and one looping floor.
	var loop_kinds := {}
	for map_seed in range(30):
		game.start_exploration(map_seed)
		var loops: int = game.generated_floor.loops
		if loop_kinds.has(loops): continue
		loop_kinds[loops] = true
		for room_id in game.room_catalog: game.exploration.visited_rooms[room_id] = true
		game.open_map()
		await grab("random-loops-%d-seed%d" % [loops,map_seed])
		game.close_map()
		if loop_kinds.size() == 2: break
	for specification in [["colonnade",["north","west","east"]],["courtyard",["south","east"]],["antechamber",["north","west"]],["storage_cells",["west","east"]],["secret_room",["west","east"]],["twin_halls",["west","east"]],["loading_bay",["north","south","west","east"]],["guard_post",["north","south","west","east"]]]:
		var room = preload("res://scripts/world/authored_rooms.gd").make_room(specification[0],specification[1])
		game.arena.configure_field(room.field,1,14)
		for door in game.doors: door.hide()
		game.get_node("HUD").hide()
		pose(Vector2(560,340) if specification[0] == "antechamber" else Vector2(560,420))
		await grab("random-"+specification[0])
		if specification[0] == "storage_cells":
			for door in room.doors:
				pose(door.arrival)
				await grab("storage-entry-"+door.id)
			pose(Vector2(1190,300))
			await grab("storage-discovery")
		if specification[0] == "secret_room":
			for door in room.doors:
				pose(door.arrival)
				await grab("secret-entry-"+door.id)
			pose(Vector2(1138,285))
			await grab("secret-discovery")
		if specification[0] == "twin_halls":
			pose(Vector2(720,580))
			await grab("twin-screen-behind")
			pose(Vector2(720,680))
			await grab("twin-screen-front")
	game.queue_free()
	await process_frame
	print("PASS: branching map, north gateway, junctions and both storage entrance/reveal views captured")
	quit()
