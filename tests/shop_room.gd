extends SceneTree
# Regression: collision-only stock placement let tall ruins cover the products and prices.
const A = preload("res://scripts/world/authored_rooms.gd")
const Reach = preload("res://scripts/world/room_reachability.gd")
const Events = preload("res://scripts/game/exploration_events.gd")
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var game = load("res://scenes/game/exploration.tscn").instantiate()
	game.random_floor = true
	game.authored_campaign = true
	root.add_child(game)
	game.set_physics_process(false)
	game.start_exploration(1)
	var shop_id: String = game.floor_data.rooms.keys().filter(func(id): return game.floor_data.rooms[id].role == "shop")[0]
	assert(game.floor_data.rooms[shop_id].template_id == "shop")
	for side in A.Shell.DIRECTIONS:
		var room = A.make_room("shop",[side])
		room.doors[0].target_room = game.start_room
		game.room_catalog[shop_id] = room
		game.exploration.room_states.erase(shop_id)
		assert(game.move_to_room(shop_id,room.doors[0].arrival))
		var state: Dictionary = game.exploration.room_state(shop_id)
		assert(state.shop.size() == 6 and state.shop_sign != null and state.teleporter != null)
		assert(Reach.reachable(room),side)
		var bounds: Array[Rect2] = [Rect2(state.shop_sign+Vector2(-56,-102),Vector2(114,120)),Rect2(state.teleporter-Vector2(52,38),Vector2(104,76))]
		var approaches: Array[Vector2] = [state.shop_sign+Vector2(0,60),state.teleporter+Events.PAD_ARRIVAL]
		for item in state.shop:
			# Includes floating merchandise above the stand and its price below.
			bounds.append(Rect2(item.pos+Vector2(-40,-64),Vector2(80,116)))
			approaches.append(item.pos+Vector2(0,60))
			assert(item.pos.distance_to(state.shop_sign) >= 144)
		for i in range(bounds.size()):
			for j in range(i+1,bounds.size()): assert(not bounds[i].intersects(bounds[j]),"Event art overlaps")
			for prop in room.field.placements:
				if prop.floor_decal: continue # Floor light cannot occlude merchandise.
				assert(not bounds[i].intersects(Rect2(prop.position+prop.visual_rect.position,prop.visual_rect.size)),"Furniture covers event art: "+prop.placement_id)
			for wall in room.field.walls: assert(not bounds[i].intersects(wall),"Wall covers event art")
		var entry: Vector2 = room.doors[0].arrival
		# Walk around the counter from the north, and through the clear customer aisle from other doors.
		var route: Array[Vector2] = [entry,Vector2(entry.x,440)]
		if side == "north": route = [entry,Vector2(560,240),Vector2(936,240),Vector2(936,440)]
		for i in range(1,route.size()): assert(Reach.clear_segment(room.field,route[i-1],route[i]),"Entry route blocked: "+side)
		for point in approaches:
			assert(Reach.clear_segment(room.field,route[-1],Vector2(point.x,440)))
			assert(Reach.clear_segment(room.field,Vector2(point.x,440),point))
			assert(not game.arena.solid(point,20),"Interaction approach blocked")
		if "--capture-shop" in OS.get_cmdline_user_args() and side == "south":
			game.get_node("HUD").hide()
			game.players[0].state.pos = Vector2(560,454)
			game.players[0].sync_visual()
			game.fit_field_camera()
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://docs/art/production/event-rooms/shop-dedicated.png")
			var camera: Camera2D = game.arena.get_node("CombatCamera")
			camera.zoom = Vector2.ONE
			camera.position = Vector2.ZERO
			camera.force_update_scroll()
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://docs/art/production/event-rooms/shop-overview.png")
	print("PASS: dedicated shop, four entrances, six products, clear art bounds and customer routes")
	game.queue_free()
	await process_frame
	quit()
