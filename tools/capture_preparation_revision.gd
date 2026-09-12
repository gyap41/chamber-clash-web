extends SceneTree
# CHAMBER_SCREENSHOT is an existing destination directory. No generated art or paid APIs.
func _initialize() -> void:
	call_deferred("run")
func capture(name_value: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var destination := OS.get_environment("CHAMBER_SCREENSHOT")
	assert(not destination.is_empty())
	assert(root.get_texture().get_image().save_png(destination.path_join(name_value+".png")) == OK)
func run() -> void:
	root.size = Vector2i(1120,800)
	var game = load("res://scenes/game/main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.new_match(42)
	var prep = game.preparation
	var m = game.match_state
	prep.set_process(false)
	m._set_products(0,["gun:1","gun:2",1,4,18])
	prep.refresh()
	await capture("01_initial")
	var starter = m.reserve_items(0)[0]
	prep.browse_entry(starter)
	prep.place_selected()
	prep.click_cell(Vector2i.ZERO)
	prep.inspect_offer(m.products[0][2].id)
	await capture("02_equipment_and_shop")
	prep.open_expansions()
	await capture("03_expansion")
	prep.cancel_placement()
	m.builds[0] = {"owned":[starter,0,1,2,3,4,5,18],"equipped":[],"positions":{},"mods":{}}
	m.temporary[0] = 19
	prep.refresh()
	prep.browse_entry(starter)
	await capture("04_eight_reserve_and_warnings")
	root.size = Vector2i(1120,600)
	await capture("05_small_window")
	game.queue_free()
	await process_frame
	print("PASS: revised preparation five states captured from actual Godot UI")
	quit()
