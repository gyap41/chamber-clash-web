extends SceneTree
const Floor = preload("res://scripts/game/authored_floor.gd")
const A = Floor.A
const Camera = preload("res://scripts/visuals/exploration_camera.gd")
func _initialize() -> void:
	var signatures := {}
	var layouts := {}
	for seed_value in range(40):
		var floor := Floor.generate(seed_value)
		assert(floor.errors.is_empty(),str(seed_value)+str(floor.errors))
		layouts[floor.layout] = true
		var edges := 0
		for room_value in floor.catalog.values(): edges += room_value.doors.size()
		assert(edges/2-floor.catalog.size()+1 == (1 if floor.layout == 2 else 0),"Incorrect loop topology")
		var counts := {}
		for id in floor.catalog:
			var art: String = floor.rooms[id].template_id
			counts[art] = counts.get(art,0)+1
			assert(counts[art] <= 2,"Room repeated more than twice: "+art)
			for door in floor.catalog[id].doors:
				assert(art != floor.rooms[door.target_room].template_id,"Adjacent duplicate: "+art)
		signatures[JSON.stringify(floor.rooms)] = true
		if seed_value < 3:
			assert(floor.rooms == Floor.generate(seed_value).rooms,"Seed must reproduce topology and templates")
	assert(layouts.size() == 3,"All three map structures must be exercised")
	assert(signatures.size() > 30,"Seeds must vary topology and template selection")
	var room = A.make_room("storage_cells",["west","east"])
	var coffer = room.field.placements.filter(func(p): return p.placement_id == "authored_cell_hidden_coffer")[0]
	var visual := Rect2(coffer.position+coffer.visual_rect.position,coffer.visual_rect.size)
	for door in room.doors:
		assert(not Rect2(Camera.origin(room.field.field_rect,door.arrival),Vector2(1120,800)/Camera.zoom()).intersects(visual),"Coffer is visible immediately from "+door.id)
	assert(Camera.visible_rect(room.field.field_rect,Vector2(1190,300)).encloses(visual),"Coffer should be revealed inside the bay")
	assert(Floor.Reach.clear_point(room.field,Vector2(1190,300)),"Discovery viewpoint must be walkable")
	for sides in [["west"],["east"],["west","east"]]:
		var secret = A.make_room("secret_room",sides)
		var box = secret.field.placements.filter(func(p): return p.placement_id == "authored_secret_coffer")[0]
		var box_rect := Rect2(box.position+box.visual_rect.position,box.visual_rect.size)
		for size_d in [false,true]:
			Camera.size_d = size_d
			for door in secret.doors:
				var full_view := Rect2(Camera.origin(secret.field.field_rect,door.arrival),Vector2(1120,800)/Camera.zoom())
				assert(not full_view.intersects(box_rect),"Secret coffer visible from "+door.id)
			assert(Camera.visible_rect(secret.field.field_rect,Vector2(1138,285)).encloses(box_rect))
		assert(Floor.Reach.clear_point(secret.field,Vector2(1138,285)))
	Camera.size_d = false
	var twin = A.make_room("twin_halls",["west","east"])
	assert("twin_partition_middle" not in twin.field.wall_ids)
	var screen = twin.field.placements.filter(func(p): return p.placement_id == "authored_twin_partition_middle")[0]
	assert(not screen.floor_decal and not screen.surface_overlay and screen.collision.has_area())
	assert(Floor.Reach.clear_point(twin.field,Vector2(720,580)))
	assert(Floor.Reach.clear_point(twin.field,Vector2(720,680)))
	print("PASS: 40 seeded branching maps, deterministic generation, role/door constraints and camera-based discovery")
	quit()
