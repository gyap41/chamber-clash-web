extends SceneTree
const Floor = preload("res://scripts/game/exploration_floor.gd")
const Reach = preload("res://scripts/world/room_reachability.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var checked := {}
	for seed_value in range(100):
		var floor := Floor.generate(seed_value,8+seed_value%5)
		assert(floor.errors.is_empty(),str(floor.errors))
		assert(Floor.validation_errors(floor).is_empty())
		var shapes := {}
		for room in floor.rooms.values(): shapes[room.shape] = true
		assert(shapes.size() == 6)
		var boss_id: String = floor.rooms.keys().filter(func(id): return floor.rooms[id].role == "boss")[0]
		assert(floor.catalog[boss_id].field.field_rect.size == Vector2(2240,1200))
		assert(floor.catalog.size() == 9+seed_value%5)
		assert(floor.catalog[boss_id].doors.size() == 1 and floor.catalog[boss_id].doors[0].id == "south")
		assert(floor.rooms[floor.catalog[boss_id].doors[0].target_room].role == "antechamber")
		var repeat := Floor.generate(seed_value,8+seed_value%5)
		assert(floor.rooms == repeat.rooms)
		for role in ["start","treasure","shop","boss","antechamber"]:
			assert(floor.rooms.values().filter(func(room): return room.role == role).size() == 1)
		for id in floor.catalog:
			var room = floor.catalog[id]
			assert(room.doors == repeat.catalog[id].doors)
			assert(room.field.walls == repeat.catalog[id].field.walls)
			assert(room.field.floor_regions == repeat.catalog[id].field.floor_regions)
			var sides: Array = room.doors.map(func(door): return door.id)
			sides.sort()
			var key: String = room.field.field_id+str(sides)+str(room.field.placements.map(func(prop): return [prop.placement_id,prop.position,prop.collision]))
			if not checked.has(key):
				assert(Reach.reachable(room),key)
				checked[key] = true
	assert(not Floor.generate(1,100).errors.is_empty())
	var blocked = Floor.generate(22).catalog.f1_r0.duplicate(true)
	blocked.field.walls.append(Rect2(128,240,864,32))
	assert(not Reach.reachable(blocked))
	var overlap := Floor.generate(22)
	overlap.rooms.f1_r1.cell = overlap.rooms.f1_r0.cell
	assert(not Floor.validation_errors(overlap).is_empty())
	print("PASS: 100 seeds, repeatability, roles, adjacency, unique cells and %d reachable template/opening combinations" % checked.size())
	quit()
