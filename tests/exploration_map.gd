extends SceneTree
# Floor map v2: room outlines from the real floor, framing from what the player has seen only.
const Production = preload("res://scripts/game/production_floor.gd")
const MapUI = preload("res://scripts/ui/exploration_map.gd")
func _initialize() -> void:
	call_deferred("run")
func open(floor: Dictionary, seen: Array, at: Vector2):
	var map = MapUI.new()
	map.floor_data = floor
	map.current = seen[0]
	map.visited = {}
	for id in seen: map.visited[id] = true
	map.room_states = {}
	map.player_pos = at
	root.add_child(map)
	return map
func bounds(map, id: String) -> Rect2:
	var result := Rect2()
	for rect in map.room_rects(id): result = rect if result.size == Vector2.ZERO else result.merge(rect)
	return result
func run() -> void:
	for seed_value in [0,5,9]:
		var floor := Production.generate(seed_value)
		assert(floor.errors.is_empty())
		var all: Array = [floor.start]
		for id in floor.rooms: if id != floor.start: all.append(id)
		var map = open(floor,all,floor.catalog[floor.start].field.spawns[0])
		var ids: Array = map.visible_rooms().keys()
		assert(ids.size() == floor.rooms.size())
		for i in range(ids.size()):
			var a := bounds(map,ids[i])
			assert(MapUI.AREA.grow(4).encloses(a),"Room outside the map area: seed %d %s" % [seed_value,ids[i]])
			for j in range(i+1,ids.size()): assert(not a.intersects(bounds(map,ids[j])),"Rooms overlap on the map")
		# The boss hall is larger than a cell and is shrunk to fit it.
		var boss: String = floor.rooms.keys().filter(func(id): return floor.rooms[id].role == "boss")[0]
		assert(map.room_scale(boss) < 1.0 and map.room_scale(floor.start) == 1.0)
		assert(bounds(map,floor.start).has_point(map.to_map(floor.start,map.player_pos)),"Marker outside current room")
		map.queue_free()
		# Only the entrance visited: its neighbours are outlines, and the frame is fitted to them alone.
		var partial = open(floor,[floor.start],Vector2(300,300))
		var seen: Dictionary = partial.visible_rooms()
		assert(seen.size() == 1+floor.catalog[floor.start].doors.size())
		assert(partial.map_scale == MapUI.MAX_SCALE,"A small explored area uses the largest scale")
		var frame := Rect2()
		for id in seen: frame = bounds(partial,id) if frame.size == Vector2.ZERO else frame.merge(bounds(partial,id))
		assert(frame.get_center().distance_to(MapUI.AREA.get_center()) < 90,"Seen rooms are centred")
		partial.queue_free()
	print("PASS exploration_map: 3 story floors fit without overlap, boss hall shrunk, marker placed, partial map framed on seen rooms")
	await process_frame
	quit()
