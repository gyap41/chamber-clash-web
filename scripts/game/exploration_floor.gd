extends RefCounted
const VERSION := 3
const Variants = preload("res://scripts/world/workshop_room_variants.gd")
const Shell = preload("res://scripts/world/workshop_room_shell.gd")
const Rooms = preload("res://scripts/game/exploration_rooms.gd")
const Layouts := [preload("res://data/fields/workshop_trial.tres"),preload("res://data/fields/workshop_annex.tres")]
const ROLES := {"start":"入口","normal":"作業室","treasure":"宝箱部屋","shop":"ショップ予定地","boss":"炉守りの間","antechamber":"ボス前室"}

# A bounded frontier-growth tree: every new cell has one existing parent.
# This RNG is private to map generation, independent of combat/reward randomness.
static func generate(seed_value: int, count: int = 10) -> Dictionary:
	if count < 8 or count > 12: return {"errors":PackedStringArray(["Floor size must be 8..12"])}
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var cells := [Vector2i.ZERO]
	var occupied := {Vector2i.ZERO:0}
	var links: Array = [[]]
	var depths := [0]
	for index in range(1,count-1):
		var frontier: Array = []
		for parent in range(cells.size()):
			for side in Shell.DIRECTIONS:
				var target: Vector2i = cells[parent]+Vector2i(Shell.DIRECTIONS[side])
				if not occupied.has(target): frontier.append([parent,side,target])
		var edge: Array = frontier[rng.randi_range(0,frontier.size()-1)]
		cells.append(edge[2])
		occupied[edge[2]] = index
		links.append([[Shell.OPPOSITE[edge[1]],edge[0]]])
		links[edge[0]].append([edge[1],index])
		depths.append(depths[edge[0]]+1)
	# Reserve a two-room branch after ordinary growth. Boss always has one south door.
	var choices: Array = []
	var best_depth := -1
	for parent in range(cells.size()):
		for side in Shell.DIRECTIONS:
			var pre: Vector2i = cells[parent]+Vector2i(Shell.DIRECTIONS[side])
			if occupied.has(pre) or occupied.has(pre+Vector2i.UP): continue
			if depths[parent] > best_depth:
				choices.clear()
				best_depth = depths[parent]
			if depths[parent] == best_depth: choices.append([parent,side,pre])
	var selected: Array = choices[rng.randi_range(0,choices.size()-1)]
	var antechamber: int = cells.size()
	var boss: int = antechamber+1
	cells.append(selected[2])
	cells.append(selected[2]+Vector2i.UP)
	links[selected[0]].append([selected[1],antechamber])
	links.append([[Shell.OPPOSITE[selected[1]],selected[0]],["north",boss]])
	links.append([["south",antechamber]])
	var specials: Array = []
	for index in range(1,antechamber): specials.append(index)
	var treasure: int = specials.pop_at(rng.randi_range(0,specials.size()-1))
	var shop: int = specials[rng.randi_range(0,specials.size()-1)]
	var catalog := {}
	var metadata := {}
	var normal_index := 0
	var shape_offset := rng.randi_range(0,3)
	for index in range(cells.size()):
		var id := "f1_r%d" % index
		var sides: Array = links[index].map(func(edge): return edge[0])
		var layout: int = 0 if index == 0 else rng.randi_range(0,3)
		var shape := "standard"
		if index == boss: shape = "hall"
		elif index in [treasure,shop,antechamber]: shape = "compact"
		elif index != 0:
			shape = ["wide","tall","elbow","standard"][(normal_index+shape_offset)%4]
			normal_index += 1
		var template_id := "workshop_%s_layout_%d" % [shape,layout]
		var room = Variants.make_room(template_id,sides,shape)
		var source = Layouts[layout % 2]
		for original in source.placements:
			if original.placement_id == "lamp_exit": continue
			if index == boss: continue # Keep the future boss arena clear.
			if "north" in sides and original.wall_shadow: continue
			if "south" in sides and original.placement_id == "bench": continue
			if layout == 2 and original.placement_id in ["anvil","metal-pallet"]: continue
			if layout == 3 and original.placement_id in ["bench","material-crate"]: continue
			Variants.place(room,original,shape)
		var role := "antechamber" if index == antechamber else "start" if index == 0 else ("boss" if index == boss else ("treasure" if index == treasure else ("shop" if index == shop else "normal")))
		var dressing := preload("res://scripts/world/ashen_foundry_dressing.gd").apply(room,role,index)
		room.display_name = "%s %02d" % [Variants.SPECS[shape].name if role == "normal" else ROLES[role],index+1]
		for door in room.doors:
			for link in links[index]:
				if link[0] == door.id: door.target_room = "f1_r%d" % link[1]
		catalog[id] = room
		metadata[id] = {"cell":cells[index],"role":role,"template_id":template_id,"shape":shape,"dressing":dressing}
	return {"version":VERSION,"seed":seed_value,"start":"f1_r0","catalog":catalog,"rooms":metadata,"errors":Rooms.validation_errors(14,catalog)}

static func validation_errors(floor: Dictionary) -> PackedStringArray:
	var errors := Rooms.validation_errors(14,floor.catalog)
	var cells := {}
	var visited := {}
	var pending: Array = [floor.start]
	while not pending.is_empty():
		var id: String = pending.pop_back()
		if visited.has(id): continue
		visited[id] = true
		for door in floor.catalog[id].doors:
			if floor.catalog.has(door.target_room): pending.append(door.target_room)
	if visited.size() != floor.catalog.size(): errors.append("Disconnected floor")
	for id in floor.catalog:
		var cell: Vector2i = floor.rooms[id].cell
		if cells.has(cell): errors.append("Overlapping room cells")
		cells[cell] = true
		for door in floor.catalog[id].doors:
			if floor.rooms.has(door.target_room) and floor.rooms[door.target_room].cell != cell+Vector2i(door.direction): errors.append("Door direction disagrees with floor coordinates")
	var bosses: Array = floor.rooms.keys().filter(func(id): return floor.rooms[id].role == "boss")
	var entries: Array = floor.rooms.keys().filter(func(id): return floor.rooms[id].role == "antechamber")
	if bosses.size() != 1 or entries.size() != 1:
		errors.append("Expected one boss room and one antechamber")
	else:
		var doors: Array = floor.catalog[bosses[0]].doors
		if doors.size() != 1 or doors[0].id != "south" or doors[0].target_room != entries[0]: errors.append("Boss requires sole south entrance from antechamber")
		if floor.catalog[entries[0]].doors.size() != 2: errors.append("Antechamber must have exactly two connections")
	return errors
