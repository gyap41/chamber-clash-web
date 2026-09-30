extends RefCounted
# Version 4 (2026-09-30, docs/planning/FLOOR_EXPANSION_PLAN.md): the main route leaves the entrance in any
# direction and turns two or three times, and side routes branch from it and from each other (sometimes
# rejoining it), so the way to the finale cannot be read from the map's shape. Two side-route terminals are
# discoveries; other dead ends are ordinary rooms. Geometry is authored; RNG selects topology, then templates.
const A = preload("res://scripts/world/authored_rooms.gd")
const Shell = A.Shell
const ExistingFloor = preload("res://scripts/game/exploration_floor.gd")
const Reach = preload("res://scripts/world/room_reachability.gd")
const VERSION := 5
const ROOMS := Vector2i(15,18)
const MAIN_ROOMS := Vector2i(6,8) # Entrance and ordinary rooms before the antechamber.
const JUNCTIONS := Vector2i(4,6)
const DISCOVERY_COUNT := 2
# Event rooms (docs/planning/FLOOR_EXPANSION_PLAN.md stage 3) use existing rooms as provisional vessels.
const TERMINAL_EVENTS := ["shop","altar"]
const EVENT_NAMES := {"shop":"工房の露店","altar":"祭壇の間","challenge":"試練の間"}
const LOOP_CHANCE := .5
const ATTEMPTS := 200

static func pick(rng: RandomNumberGenerator, pool: Array) -> String:
	return pool[rng.randi_range(0,pool.size()-1)]

static func generate(seed_value: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var nodes: Array = []
	for attempt in range(ATTEMPTS):
		nodes = topology(rng)
		if not nodes.is_empty(): break
	assert(not nodes.is_empty(),"No floor topology for seed %d" % seed_value)
	assign_templates(nodes,rng)
	var catalog := {}
	var metadata := {}
	for index in range(nodes.size()):
		var node: Dictionary = nodes[index]
		var id := "authored_%d" % index
		var sides: Array = node.links.map(func(edge): return edge[0])
		var room = A.make_room(node.art,sides)
		room.field.field_id = id
		room.display_name = EVENT_NAMES.get(node.role,A.NAMES[node.art]) if node.role != "boss" else "最奥の広間（ボス配置予定）"
		for door in room.doors:
			for edge in node.links:
				if door.id == edge[0]: door.target_room = "authored_%d" % edge[1]
		catalog[id] = room
		metadata[id] = {"cell":node.cell,"role":node.role,"template_id":node.art,"teleporter":node.get("teleporter",false)}
	var floor := {"version":VERSION,"seed":seed_value,"loops":loop_count(nodes),"start":"authored_0","catalog":catalog,"rooms":metadata,"errors":PackedStringArray()}
	floor.errors = validation_errors(floor)
	return floor

# One attempt at the room graph; empty when the walk runs into itself or misses a target.
static func topology(rng: RandomNumberGenerator) -> Array:
	var nodes: Array = []
	var occupied := {}
	var sides: Array = Shell.DIRECTIONS.keys()
	add_node(nodes,occupied,Vector2i.ZERO,"camp_remains","start")
	# Main route: turns fall on distinct interior steps, so every straight run is at least one room long.
	var heading: String = pick(rng,sides)
	var steps := rng.randi_range(MAIN_ROOMS.x,MAIN_ROOMS.y)-1
	var interior: Array = range(1,steps)
	var turns := {}
	for turn in range(rng.randi_range(2,3)):
		turns[interior.pop_at(rng.randi_range(0,interior.size()-1))] = true
	for step in range(steps):
		if turns.has(step): heading = turn_from(heading,rng)
		var cell: Vector2i = nodes.back().cell+Vector2i(Shell.DIRECTIONS[heading])
		if occupied.has(cell): return []
		connect_cells(nodes,nodes.size()-1,add_node(nodes,occupied,cell,"","normal"))
	# The finale keeps its sole south entrance: the antechamber is entered from west, east or south.
	var last: int = nodes.size()-1
	var gateways: Array = []
	for entrance in ["west","east","south"]:
		var gate: Vector2i = nodes[last].cell-Vector2i(Shell.DIRECTIONS[entrance])
		if not occupied.has(gate) and not occupied.has(gate+Vector2i.UP): gateways.append(gate)
	if gateways.is_empty(): return []
	var gate: Vector2i = gateways[rng.randi_range(0,gateways.size()-1)]
	var pre := add_node(nodes,occupied,gate,"antechamber","antechamber")
	connect_cells(nodes,last,pre)
	connect_cells(nodes,pre,add_node(nodes,occupied,gate+Vector2i.UP,"root_hall","boss"))
	# Side routes grow from any ordinary room, including earlier side routes, and may bend.
	var target := rng.randi_range(ROOMS.x,ROOMS.y)
	while nodes.size() < target:
		var options: Array = []
		for index in range(nodes.size()):
			if nodes[index].role not in ["start","normal"]: continue
			for side in sides:
				if not occupied.has(nodes[index].cell+Vector2i(Shell.DIRECTIONS[side])): options.append([index,side])
		if options.is_empty(): return []
		var option: Array = options[rng.randi_range(0,options.size()-1)]
		var parent: int = option[0]
		var side: String = option[1]
		for step in range(mini(rng.randi_range(1,3),target-nodes.size())):
			var cell: Vector2i = nodes[parent].cell+Vector2i(Shell.DIRECTIONS[side])
			if occupied.has(cell): break
			var next := add_node(nodes,occupied,cell,"","normal")
			connect_cells(nodes,parent,next)
			parent = next
			if rng.randf() < .4: side = turn_from(side,rng)
	# A side route sometimes rejoins a distant part of the floor: a detour that never shortens the way to the finale.
	if rng.randf() < LOOP_CHANCE:
		var distance := distances(nodes,0)
		var joins: Array = []
		var finale: int = pre+1
		for a in range(nodes.size()):
			for b in range(a+1,nodes.size()):
				if nodes[a].role not in ["start","normal"] or nodes[b].role not in ["start","normal"]: continue
				if nodes[a].links.size() >= 3 or nodes[b].links.size() >= 3: continue
				if (nodes[a].cell-nodes[b].cell).length_squared() != 1 or linked(nodes,a,b): continue
				if absi(distance[a]-distance[b]) < 3: continue
				# Through the join, the nearer room reaches the farther one's side of the tree in one step.
				var near: int = a if distance[a] < distance[b] else b
				var far: int = b if near == a else a
				if distance[near]+1+distances(nodes,far)[finale] >= distance[finale]: joins.append([a,b])
		if not joins.is_empty():
			var join: Array = joins[rng.randi_range(0,joins.size()-1)]
			connect_cells(nodes,join[0],join[1])
	var junctions: int = nodes.filter(func(node): return node.links.size() >= 3).size()
	if junctions < JUNCTIONS.x or junctions > JUNCTIONS.y: return []
	# Dead ends hold the discoveries and the terminal events; other dead ends stay ordinary rooms.
	var leaves: Array = range(nodes.size()).filter(func(index): return nodes[index].role == "normal" and nodes[index].links.size() == 1)
	var terminals: Array = []
	for count in range(DISCOVERY_COUNT): terminals.append("discovery")
	terminals.append_array(TERMINAL_EVENTS)
	if leaves.size() < terminals.size(): return []
	for event in terminals:
		nodes[leaves.pop_at(rng.randi_range(0,leaves.size()-1))].role = event
	# The challenge is an optional side-route room: indices after the finale were grown as side routes.
	var side: Array = range(pre+2,nodes.size()).filter(func(index): return nodes[index].role == "normal")
	if side.is_empty(): return []
	nodes[side[rng.randi_range(0,side.size()-1)]].role = "challenge"
	# Teleporters: entrance, antechamber, shop, and up to two junctions spread across the floor.
	var pads: Array = [0,pre]
	pads.append_array(range(nodes.size()).filter(func(index): return nodes[index].role == "shop"))
	var hubs: Array = range(nodes.size()).filter(func(index): return nodes[index].role == "normal" and nodes[index].links.size() >= 3)
	while pads.size() < 5 and not hubs.is_empty():
		var hub: int = hubs.pop_at(rng.randi_range(0,hubs.size()-1))
		var spread := distances(nodes,hub)
		if pads.all(func(pad): return spread[pad] >= 3): pads.append(hub)
	for pad in pads: nodes[pad].teleporter = true
	return nodes

static func turn_from(heading: String, rng: RandomNumberGenerator) -> String:
	var options: Array = ["west","east"] if heading in ["north","south"] else ["north","south"]
	return pick(rng,options)

static func linked(nodes: Array, a: int, b: int) -> bool:
	return nodes[a].links.any(func(edge): return edge[1] == b)

static func distances(nodes: Array, from: int) -> Array:
	var result: Array = []
	result.resize(nodes.size())
	result.fill(-1)
	result[from] = 0
	var pending: Array = [from]
	while not pending.is_empty():
		var index: int = pending.pop_front()
		for edge in nodes[index].links:
			if result[edge[1]] < 0:
				result[edge[1]] = result[index]+1
				pending.append(edge[1])
	return result

static func loop_count(nodes: Array) -> int:
	var edges := 0
	for node in nodes: edges += node.links.size()
	return edges/2-nodes.size()+1

# Select after topology is complete, using actual openings and least-used compatible rooms.
# Fixed start/finale identities also count; no room shares its identity with a neighbour.
static func assign_templates(nodes: Array, rng: RandomNumberGenerator) -> void:
	var counts := {}
	for node in nodes:
		if node.role in ["normal","discovery","challenge"] or node.role in TERMINAL_EVENTS:
			node.art = ""
		else:
			counts[node.art] = counts.get(node.art,0)+1
	for node in nodes:
		if not node.art.is_empty(): continue
		var sides := A.canonical_sides(node.links.map(func(edge): return edge[0]))
		var ordinary: Array = A.COMBAT_ROOMS.filter(func(art): return art != "camp_remains")
		# Event vessels may also be ordinary rooms, so a floor never needs one terminal room three times.
		var pool: Array = A.DISCOVERIES if node.role == "discovery" else (A.DISCOVERIES+ordinary if node.role in TERMINAL_EVENTS else ordinary)
		# The chapel's altar makes it the altar's vessel whenever its openings allow.
		if node.role == "altar" and sides in A.connection_sets("chapel"): pool = ["chapel"]
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
	var junctions := 0
	var discoveries := 0
	for id in floor.catalog:
		var room = floor.catalog[id]
		var meta: Dictionary = floor.rooms[id]
		var sides := A.canonical_sides(room.doors.map(func(d): return d.id))
		if sides not in A.connection_sets(meta.template_id): errors.append("Unsupported openings: "+id)
		if not Reach.reachable(room): errors.append("Unreachable: "+id)
		if room.doors.size() >= 3: junctions += 1
		if meta.role == "discovery":
			discoveries += 1
			if room.doors.size() != 1 or meta.template_id not in A.DISCOVERIES: errors.append("Discovery must be a suitable terminal")
		if meta.role == "antechamber":
			for door in room.doors:
				if door.id == "north" and floor.rooms[door.target_room].role != "boss": errors.append("Gateway must lead to finale")
	if floor.catalog.size() < ROOMS.x or floor.catalog.size() > ROOMS.y: errors.append("Room count outside %s" % ROOMS)
	if junctions < JUNCTIONS.x or junctions > JUNCTIONS.y: errors.append("Junction count outside %s" % JUNCTIONS)
	if discoveries != DISCOVERY_COUNT: errors.append("Expected %d discoveries" % DISCOVERY_COUNT)
	for event in TERMINAL_EVENTS+["challenge"]:
		var rooms: Array = floor.rooms.keys().filter(func(id): return floor.rooms[id].role == event)
		if rooms.size() != 1: errors.append("Expected one %s room" % event)
		elif event in TERMINAL_EVENTS and floor.catalog[rooms[0]].doors.size() != 1: errors.append("%s must be a terminal" % event)
	return errors
