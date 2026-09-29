extends SceneTree
# Hand-authored room trial: rooms validate like generated rooms, every door side stays usable, all art loads.
const Authored = preload("res://scripts/world/authored_rooms.gd")
const Rooms = preload("res://scripts/game/exploration_rooms.gd")
const Reach = preload("res://scripts/world/room_reachability.gd")
const RADIUS := 14.0
func _initialize() -> void:
	var catalog: Dictionary = Authored.catalog()
	assert(catalog.size() == 20)
	var errors := Rooms.validation_errors(RADIUS,catalog)
	assert(errors.is_empty(),str(errors))
	for id in catalog:
		var room = catalog[id]
		var field = room.field
		assert(Reach.reachable(room),"unreachable: "+id)
		for prop in field.placements:
			assert(prop.validation_errors(field.field_rect).is_empty(),id+" "+prop.placement_id)
			assert(prop.texture != null or prop.placement_id.begins_with("authored_block_"),id+" "+prop.placement_id)
		# Keep all four side-centre door corridors clear (wall line to 100px inside), for any future door.
		var size: Vector2 = field.field_rect.size
		var lanes := [Rect2(size.x*.5-72,80,144,148),Rect2(size.x*.5-72,size.y-190,144,120),
			Rect2(70,size.y*.5-56,130,112),Rect2(size.x-200,size.y*.5-56,130,112)]
		# The original four reserve future cardinal openings. New rooms explicitly support west/east only.
		if Authored.ORDER.find(id) >= 4:
			lanes.clear()
			for door in room.doors:
				var vertical: bool = absf(door.direction.y) > .5
				var start: Vector2 = door.position.min(door.arrival)
				var finish: Vector2 = door.position.max(door.arrival)
				lanes.append(Rect2(start-Vector2(door.width*.5,30) if vertical else start-Vector2(30,door.width*.5),finish-start+(Vector2(door.width,60) if vertical else Vector2(60,door.width))))
		for lane in lanes:
			for prop in field.placements:
				if prop.collision == Rect2(): continue
				assert(not lane.intersects(Rect2(prop.position+prop.collision.position,prop.collision.size)),id+" blocks a door lane: "+prop.placement_id)
			for i in range(field.walls.size()):
				if field.wall_ids[i].begins_with("stub"):
					assert(not lane.intersects(field.walls[i]),id+" wall stub in a door lane")
		# Floor-standing pieces must not be drawn into a wall: the lower part of the picture (its footprint on
		# the floor) stays clear of every wall. Pieces attached to a wall (lamps, buttresses, wall-backed furniture)
		# and invisible blocks are skipped.
		for prop in field.placements:
			if prop.floor_decal or prop.surface_overlay or prop.texture == null or prop.wall_shadow or prop.placement_id.contains("lamp") or prop.placement_id.contains("buttress"): continue
			var visual := Rect2(prop.position+prop.visual_rect.position,prop.visual_rect.size)
			var foot := Rect2(visual.position.x+visual.size.x*.05,visual.end.y-visual.size.y*.3,visual.size.x*.9,visual.size.y*.3)
			for wall in field.walls:
				assert(not foot.intersects(wall),"%s: %s is drawn into a wall" % [id,prop.placement_id])
		# No walkable pocket sealed off by collision: flood the 16px grid of clear points from the spawn.
		var step := 16.0
		var start: Vector2 = field.spawns[0]
		var seen := {Vector2i.ZERO:true}
		var pending: Array[Vector2i] = [Vector2i.ZERO]
		var cursor := 0
		while cursor < pending.size():
			var cell := pending[cursor]
			cursor += 1
			for offset in [Vector2i.RIGHT,Vector2i.LEFT,Vector2i.UP,Vector2i.DOWN]:
				var next: Vector2i = cell+offset
				if seen.has(next): continue
				var point := start+Vector2(next)*step
				if Reach.clear_point(field,point) and Reach.clear_segment(field,start+Vector2(cell)*step,point):
					seen[next] = true
					pending.append(next)
		var trapped := 0
		for gx in range(-int(start.x/step),int((size.x-start.x)/step)+1):
			for gy in range(-int(start.y/step),int((size.y-start.y)/step)+1):
				var point := start+Vector2(gx,gy)*step
				if not seen.has(Vector2i(gx,gy)) and Reach.clear_point(field,point): trapped += 1
		assert(trapped == 0,"%s has %d walkable points sealed off" % [id,trapped])
	assert(verify_gallery_routes(catalog.collapsed_gallery),"Gallery route verification failed")
	assert(not Reach.clear_point(catalog.cistern.field,Vector2(560,350)),"Reservoir water must not be walkable")
	assert(not Reach.clear_point(catalog.overlook.field,Vector2(720,318)),"Distant view must not be walkable")
	assert(Reach.clear_point(catalog.overlook.field,Vector2(720,600)),"Viewing balcony must remain walkable")
	# The lined pit and parapet must stop entry over their entire span, including the module join.
	for x in range(330,1120,24):
		assert(not Reach.clear_point(catalog.overlook.field,Vector2(x,400)),"Walkable pit")
		assert(not Reach.clear_segment(catalog.overlook.field,Vector2(x,600),Vector2(x,480)),"Gap in overlook parapet")
	assert(Reach.clear_segment(catalog.overlook.field,Vector2(340,600),Vector2(1100,600)),"Observation walkway blocked")
	print("PASS: authored rooms validate, reachable, door lanes clear, nothing drawn into walls, no sealed pockets")
	quit()

func verify_gallery_routes(room) -> bool:
	# The principal route must encounter the collapse, with two usable alternatives rather than a dead end.
	var west: Vector2 = room.doors[0].arrival
	var east: Vector2 = room.doors[1].arrival
	assert(not Reach.clear_segment(room.field,west,east),"Gallery collapse must interrupt the straight east-west route")
	var routes := [
		[west,Vector2(390,400),Vector2(390,220),Vector2(650,220),Vector2(650,315),Vector2(700,335),Vector2(740,400),east],
		[west,Vector2(390,450),Vector2(400,506),Vector2(720,506),east]
	]
	for route_index in range(routes.size()):
		var route: Array = routes[route_index]
		for i in range(route.size()-1):
			var start: Vector2 = route[i]
			var finish: Vector2 = route[i+1]
			# Player radius is already included by Reach. A +/-18px band of centres gives 64px total clearance.
			var side := (finish-start).normalized().orthogonal()*18
			for offset in [Vector2.ZERO,side,-side]:
				assert(Reach.clear_segment(room.field,start+offset,finish+offset),"Gallery bypass %d segment %d needs 64px clearance" % [route_index,i])
	print("PASS: gallery straight route interrupted, north and south bypasses have at least 64px clearance")
	return true
