extends "res://tests/exploration_treasure_supplies.gd"
const Dressing = preload("res://scripts/world/ashen_foundry_dressing.gd")

func run() -> void:
	root.size = Vector2i(1120,800)
	var source = preload("res://data/rooms/workshop_trial.tres")
	var room = source.duplicate(true)
	var old_theme = source.field.theme
	var old_count: int = source.field.placements.size()
	Dressing.apply(room,"normal",1)
	assert(source.field.theme == old_theme and source.field.placements.size() == old_count)
	assert(room.field.walls == source.field.walls and room.doors == source.doors)
	var count: int = room.field.placements.size()
	Dressing.apply(room,"normal",1)
	assert(room.field.placements.size() == count)
	for prop in room.field.placements:
		if prop.floor_decal: assert(prop.collision == Rect2() and prop.light_radius == 0)
	var game = load("res://scenes/game/exploration.tscn").instantiate()
	game.random_floor = true
	root.add_child(game)
	game.set_physics_process(false)
	game.start_exploration(22)
	game.set_pause_reason("focus",false)
	for identity in ["hearth","overgrown","foundry"]:
		var id: String = game.floor_data.rooms.keys().filter(func(key): return game.floor_data.rooms[key].dressing == identity and game.floor_data.rooms[key].role != "boss")[0]
		enter(game,id)
		game.Encounter.retire(game)
		game.players[0].state.pos = Vector2(440,300)
		game.players[0].sync_visual()
		game.fit_field_camera()
		game.refresh_hud()
		await capture("ashen-"+identity)
		for prop in game.arena.get_node("StageBackground").get_children(): assert(not prop.definition.floor_decal)
	var treasure: String = game.floor_data.rooms.keys().filter(func(key): return game.floor_data.rooms[key].role == "treasure")[0]
	enter(game,treasure)
	game.players[0].state.pos = Vector2(440,350)
	game.players[0].sync_visual()
	game.fit_field_camera()
	game.refresh_hud()
	await capture("ashen-treasure")
	# Measured opaque bounds must exclude the faint alpha dust near atlas edges.
	assert(Dressing.sprite(Dressing.FURNISHINGS,0).region == Rect2(72,148,523,407))
	assert(Dressing.sprite(Dressing.ROOT_ENTRIES,0).region.end.y == 658)
	var malformed = Dressing.Placement.new()
	malformed.placement_id = "invalid_shadow"
	malformed.position = Vector2(200,200)
	malformed.shadow_rect = Rect2(0,0,-1,4)
	assert(not malformed.validation_errors(Rect2(0,0,1120,600)).is_empty())
	var seen := {}
	var generated = preload("res://scripts/game/exploration_floor.gd").generate(22)
	for generated_room in generated.catalog.values():
		for prop in generated_room.field.placements:
			seen[prop.placement_id] = true
			if prop.floor_motif != 0:
				assert(prop.floor_decal and prop.collision == Rect2())
				var bed := Rect2(prop.position+prop.visual_rect.position,prop.visual_rect.size)
				assert(generated_room.field.floor_regions.any(func(region): return region.encloses(bed)))
			if prop.surface_overlay: assert(prop.collision == Rect2())
			if prop.placement_id.begins_with("ashen_") and prop.collision.has_area():
				var footprint := Rect2(prop.position+prop.collision.position,prop.collision.size)
				for wall in generated_room.field.walls: assert(not footprint.intersects(wall))
	for id in ["mold_rack","quench_trough","covered_crates","tea_table","root_entry_0","root_entry_1","moss_0","nest","casting_bed"]:
		assert(seen.has("ashen_"+id),"Missing applied asset: "+id)
	game.queue_free()
	await process_frame
	var fixed = load("res://scenes/game/exploration.tscn").instantiate()
	fixed.random_floor = false
	root.add_child(fixed)
	fixed.set_physics_process(false)
	fixed.start_exploration(22)
	fixed.set_pause_reason("focus",false)
	await capture("fixed-additions")
	fixed.queue_free()
	await process_frame
	print("PASS: private story theme, idempotent dressing, unchanged geometry and floor-only decals")
	quit()
