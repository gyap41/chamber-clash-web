extends SceneTree
# Standalone actual-room review: four gates repeatedly close and reopen.
var game: Node
var elapsed: float = 0.0
var captured: Dictionary = {}
var output_folder: String = "res://docs/art/production/ashen-foundry-v2/gate-adopted/"
var view_direction: String = ""
var recording: bool = false
var frame_index: int = 0
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	recording = "--record-gate" in OS.get_cmdline_user_args()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--preview-candidate="):
			output_folder = "res://assets/candidates/"+arg.trim_prefix("--preview-candidate=")+"/views/"
		if arg.begins_with("--gate-view="): view_direction = arg.trim_prefix("--gate-view=")
	if "--gate-north" in OS.get_cmdline_user_args(): view_direction = "north"
	root.size = Vector2i(1120,800)
	game = load("res://scenes/game/workshop_variants_preview.tscn").instantiate()
	root.add_child(game)
	game.room_catalog = preload("res://scripts/world/four_way_demo.gd").catalog()
	for room in game.room_catalog.values():
		preload("res://scripts/world/ashen_foundry_dressing.gd").apply(room,"normal",1)
	game.start_room = "crossroads"
	if "--gate-production" in OS.get_cmdline_user_args():
		var floor_data: Dictionary = preload("res://scripts/game/production_floor.gd").generate(1)
		assert(floor_data.errors.is_empty())
		game.room_catalog = floor_data.catalog
		game.start_room = floor_data.start
		for id in game.room_catalog:
			var room = game.room_catalog[id]
			if room.doors.any(func(entry: Dictionary) -> bool: return entry.id == view_direction):
				game.start_room = id
				break
		output_folder += "production/"
		print("Gate production room: ",game.start_room)
	game.start_exploration(1)
	game.set_physics_process(false)
	game.get_node("HUD").hide()
	game.players[0].state.pos = Vector2(560,300)
	game.players[0].sync_visual()
	game.fit_field_camera()
	game.arena.get_node("CombatCamera").zoom = Vector2(.85,.85)
	game.arena.get_node("CombatCamera").position = Vector2(560,300)-Vector2(560,400)/.85
	game.arena.get_node("CombatCamera").force_update_scroll()
	if not view_direction.is_empty():
		for entry in game.room_data(game.start_room).doors:
			if entry.id != view_direction: continue
			game.players[0].state.pos = entry.arrival
			game.players[0].sync_visual()
			game.fit_field_camera()
		output_folder += view_direction+"/"
func _process(dt: float) -> bool:
	if game == null: return false
	var step_time: float = .05 if recording else dt
	elapsed += step_time
	var closed: bool = fmod(elapsed,5.0) < 2.5
	for door in game.doors:
		door.set_locked(closed)
		door.step(step_time)
	if recording:
		if frame_index < 100:
			capture_frame.call_deferred(frame_index)
			frame_index += 1
		else: quit()
	if "--capture-gate" in OS.get_cmdline_user_args():
		for item in [[1.0,"closed"],[2.8,"opening"],[3.5,"open"]]:
			if elapsed >= item[0] and not captured.has(item[1]):
				captured[item[1]] = true
				capture.call_deferred(item[1])
		if elapsed > 4.0 and not recording: quit()
	return false
func capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	var folder: String = output_folder
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	root.get_texture().get_image().save_png(folder+label+".png")
func capture_frame(index: int) -> void:
	await RenderingServer.frame_post_draw
	var folder: String = "res://.local/gate-frames/"+output_folder.trim_prefix("res://")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	root.get_texture().get_image().save_png(folder+"%03d.png" % index)
