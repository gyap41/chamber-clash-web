extends "res://tests/exploration_rooms.gd"
func find_ambience(game) -> Node:
	return game.arena.find_child("CisternAmbience",true,false)
func run() -> void:
	root.size = Vector2i(1120,800)
	root.content_scale_size = root.size
	var game = load("res://scenes/game/exploration.tscn").instantiate()
	game.room_catalog = preload("res://scripts/world/authored_rooms.gd").catalog()
	game.start_room = "cistern"
	game.preserve_room_dressing = true
	game.encounters_enabled = false
	root.add_child(game)
	game.set_physics_process(false)
	game.set_pause_reason("focus",false)
	var ambience = find_ambience(game)
	assert(ambience != null and ambience.pause_owner == game)
	ambience.set_process(false)
	ambience.step(1.0)
	assert(ambience.water_material.get_shader_parameter("motion_time") == 1.0)
	game.set_pause_reason("menu",true)
	ambience._process(2.0)
	assert(ambience.elapsed == 1.0)
	game.set_pause_reason("menu",false)
	ambience._process(.5)
	assert(ambience.elapsed == 1.5)
	assert(not ambience.get_child(0).show_behind_parent)
	assert(game.arena.find_children("CisternAmbience","",true,false).size() == 2)
	game.set_pause_reason("test",true)
	game.players[0].state.pos = Vector2(560,565)
	game.players[0].sync_visual()
	game.fit_field_camera()
	game.arena.get_node("CombatCamera").zoom = Vector2.ONE
	game.arena.get_node("CombatCamera").position = Vector2(0,-30)
	game.arena.get_node("CombatCamera").force_update_scroll()
	game.refresh_hud()
	await capture("cistern-water-1")
	var before: Image
	if "--capture" in OS.get_cmdline_user_args(): before = root.get_texture().get_image()
	ambience.step(2.0)
	await capture("cistern-water-2")
	if before != null:
		var after := root.get_texture().get_image()
		var changed := 0
		for x in range(470,650,3):
			for y in range(345,425,3):
				if before.get_pixel(x,y) != after.get_pixel(x,y): changed += 1
		assert(changed > 500,"Water must visibly change, not merely update a hidden shader clock")
		assert(before.get_pixel(440,410) == after.get_pixel(440,410),"Stone rim must stay fixed")
	var old = weakref(ambience)
	assert(game.switch_field(game.room_data("camp_remains").field).is_empty())
	await process_frame
	assert(old.get_ref() == null and find_ambience(game) == null)
	var fire = game.arena.find_child("PropFire",true,false)
	assert(fire != null and fire.kind == 2)
	fire.set_process(false)
	var initial_time: float = fire.elapsed
	fire._process(1.0)
	assert(fire.elapsed == initial_time)
	game.set_pause_reason("test",false)
	fire._process(.4)
	assert(fire.elapsed > initial_time)
	game.set_pause_reason("test",true)
	game.players[0].state.pos = Vector2(560,565)
	game.players[0].sync_visual()
	await capture("camp-fire-1")
	var energy: float = fire.light.energy
	fire.step(.3)
	assert(not is_equal_approx(energy,fire.light.energy))
	await capture("camp-fire-2")
	var old_fire = weakref(fire)
	assert(game.switch_field(game.room_data("casting_line").field).is_empty())
	await process_frame
	assert(old_fire.get_ref() == null)
	assert(game.arena.find_child("PropFire",true,false).kind == 3)
	assert(find_ambience(game) != null and not find_ambience(game).sunlight)
	game.arena.get_node("CombatCamera").zoom = Vector2.ONE
	game.arena.get_node("CombatCamera").position = Vector2(0,-30)
	game.arena.get_node("CombatCamera").force_update_scroll()
	await capture("furnace-fire")
	assert(game.switch_field(game.room_data("cistern").field).is_empty())
	assert(find_ambience(game) != null)
	game.queue_free()
	await process_frame
	print("PASS: water rendering, fixed rim, small troughs, fire lights, pause/resume and room cleanup")
	quit()
