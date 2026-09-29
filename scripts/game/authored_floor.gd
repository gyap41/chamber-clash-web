extends RefCounted
# Three explorable structures: straight, bent main route, and rejoining loop; two discovery terminals.
# Geometry is authored; RNG selects compatible templates, branch directions and lengths.
const A = preload("res://scripts/world/authored_rooms.gd")
const Shell = A.Shell
const ExistingFloor = preload("res://scripts/game/exploration_floor.gd")
const Reach = preload("res://scripts/world/room_reachability.gd")
const VERSION := 3

static func pick(rng: RandomNumberGenerator, pool: Array) -> String:
	return pool[rng.randi_range(0,pool.size()-1)]

static func generate(seed_value: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var nodes: Array = []
	var occupied := {}
	var layout := rng.randi_range(0,2)
	var sign_y := 1 if rng.randf() < .5 else -1
	var main_cells: Array[Vector2i] = []
	if layout == 1:
		main_cells.assign([Vector2i(0,0),Vector2i(1,0),Vector2i(1,sign_y),Vector2i(2,sign_y),Vector2i(3,sign_y)])
	else:
		for x in range(rng.randi_range(4,6)): main_cells.append(Vector2i(x,0))
	for cell in main_cells:
		var index := add_node(nodes,occupied,cell,"camp_remains" if nodes.is_empty() else "","start" if nodes.is_empty() else "normal")
		if index > 0: connect_cells(nodes,index-1,index)
	var pre := add_node(nodes,occupied,main_cells.back()+Vector2i.RIGHT,"antechamber","antechamber")
	connect_cells(nodes,pre-1,pre)
	var boss := add_node(nodes,occupied,nodes[pre].cell+Vector2i.UP,"root_hall","boss")
	connect_cells(nodes,pre,boss)
	if layout == 2:
		# Alternative route rejoins the main route; it is not another dead-end branch.
		var parent := 1
		for x in range(1,4):
			var next := add_node(nodes,occupied,Vector2i(x,sign_y),"","normal")
			connect_cells(nodes,parent,next)
			parent = next
		connect_cells(nodes,parent,3)
	var origins := {}
	for branch in range(2):
		var options: Array = []
		for index in range(1,nodes.size()):
			if nodes[index].role != "normal" or origins.has(index): continue
			for vertical in ["north","south"]:
				for depth in [0,1,2]:
					var at: Vector2i = nodes[index].cell
					var clear := true
					for step in range(depth):
						at += Vector2i(Shell.DIRECTIONS[vertical])
						if occupied.has(at): clear = false
					if not clear: continue
					for turn_side in ["west","east"]:
						if not occupied.has(at+Vector2i(Shell.DIRECTIONS[turn_side])):
							options.append([index,vertical,depth,turn_side])
		assert(not options.is_empty(),"No compatible branch route")
		# Loop maps already have a detour; keep their optional discoveries short.
		if layout == 2:
			var shortest := 3
			for option in options: shortest = mini(shortest,option[2])
			options = options.filter(func(option): return option[2] == shortest)
		var option: Array = options[rng.randi_range(0,options.size()-1)]
		var parent: int = option[0]
		origins[parent] = true
		var at: Vector2i = nodes[parent].cell
		for step in range(option[2]):
			at += Vector2i(Shell.DIRECTIONS[option[1]])
			var next := add_node(nodes,occupied,at,"","normal")
			connect_cells(nodes,parent,next)
			parent = next
		var terminal := add_node(nodes,occupied,at+Vector2i(Shell.DIRECTIONS[option[3]]),"","discovery")
		connect_cells(nodes,parent,terminal)
	assign_templates(nodes,rng)
	var catalog := {}
	var metadata := {}
	for index in range(nodes.size()):
		var node: Dictionary = nodes[index]
		var id := "authored_%d" % index
		var sides: Array = node.links.map(func(edge): return edge[0])
		var room = A.make_room(node.art,sides)
		room.field.field_id = id
		room.display_name = A.NAMES[node.art] if node.role != "boss" else "最奥の広間（ボス配置予定）"
		for door in room.doors:
			for edge in node.links:
				if door.id == edge[0]: door.target_room = "authored_%d" % edge[1]
		catalog[id] = room
		metadata[id] = {"cell":node.cell,"role":node.role,"template_id":node.art}
	var floor := {"version":VERSION,"seed":seed_value,"layout":layout,"start":"authored_0","catalog":catalog,"rooms":metadata,"errors":PackedStringArray()}
	floor.errors = validation_errors(floor)
	return floor

# Select after topology is complete, using actual openings and least-used compatible rooms.
# Fixed start/finale identities also count; no room shares its identity with a neighbour.
static func assign_templates(nodes: Array, rng: RandomNumberGenerator) -> void:
	var counts := {}
	for node in nodes:
		if node.role in ["normal","discovery"]:
			node.art = ""
		else:
			counts[node.art] = counts.get(node.art,0)+1
	for node in nodes:
		if not node.art.is_empty(): continue
		var sides := A.canonical_sides(node.links.map(func(edge): return edge[0]))
		var pool: Array = A.DISCOVERIES if node.role == "discovery" else A.PASSAGES + ["colonnade","courtyard"]
		var neighbours: Array = node.links.map(func(edge): return nodes[edge[1]].art)
		var candidates: Array = []
		var minimum := 10000
		for art in pool:
			if art in neighbours or sides not in A.connection_sets(art): continue
			var used: int = counts.get(art,0)
			if used < minimum:
				candidates.clear()
				minimum = used
			if used == minimum: candidates.append(art)
		assert(not candidates.is_empty(),"No diverse compatible room for "+str(sides))
		node.art = pick(rng,candidates)
		counts[node.art] = counts.get(node.art,0)+1

static func add_node(nodes: Array, occupied: Dictionary, cell: Vector2i, art: String, role: String) -> int:
	assert(not occupied.has(cell),"Duplicate authored map cell")
	var index := nodes.size()
	occupied[cell] = index
	nodes.append({"cell":cell,"art":art,"role":role,"links":[]})
	return index

static func connect_cells(nodes: Array, from: int, to: int) -> void:
	var delta: Vector2i = nodes[to].cell-nodes[from].cell
	for side in Shell.DIRECTIONS:
		if Vector2i(Shell.DIRECTIONS[side]) == delta:
			connect_nodes(nodes,from,to,side)
			return
	assert(false,"Non-adjacent map cells")

static func connect_nodes(nodes: Array, from: int, to: int, side: String) -> void:
	nodes[from].links.append([side,to])
	nodes[to].links.append([Shell.OPPOSITE[side],from])

static func validation_errors(floor: Dictionary) -> PackedStringArray:
	var errors := ExistingFloor.validation_errors(floor)
	var branches := 0
	var discoveries := 0
	for id in floor.catalog:
		var room = floor.catalog[id]
		var meta: Dictionary = floor.rooms[id]
		var sides := A.canonical_sides(room.doors.map(func(d): return d.id))
		if sides not in A.connection_sets(meta.template_id): errors.append("Unsupported openings: "+id)
		if not Reach.reachable(room): errors.append("Unreachable: "+id)
		if room.doors.size() >= 3: branches += 1
		if meta.role == "discovery":
			discoveries += 1
			if room.doors.size() != 1 or meta.template_id not in A.DISCOVERIES: errors.append("Discovery must be a suitable terminal")
		if meta.role == "antechamber":
			for door in room.doors:
				if door.id == "north" and floor.rooms[door.target_room].role != "boss": errors.append("Gateway must lead to finale")
	if branches < 2 or discoveries != 2: errors.append("Expected two optional branches and discoveries")
	return errors
