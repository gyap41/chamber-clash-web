extends RefCounted
# Read-only geometry shared by preparation and combat. Mutations stay in MatchState.
const Items = preload("res://scripts/game/item_identity.gd")
const WeaponShapes = preload("res://scripts/catalog/weapon_shapes.gd")
const RelicShapes = preload("res://scripts/catalog/relic_shapes.gd")
const Expansions = preload("res://scripts/catalog/bag_expansions.gd")
const MAX_GRID_SIZE := Vector2i(6,6)
const RESERVE_CAPACITY := 8
const MAX_CARRIED_WEAPONS := 8
const MAX_AREA := 24

static func shape_of(entry) -> Array:
	return WeaponShapes.shape(Items.gun_id(entry)) if Items.is_gun(entry) else RelicShapes.shape(Items.relic_id(entry))

static func usable_cells(build: Dictionary) -> Dictionary:
	var cells := {}
	for y in range(2):
		for x in range(4): cells[Vector2i(x,y)] = true
	for patch in build.get("bag_expansions",[]):
		for offset in Expansions.SHAPES[patch.shape]: cells[patch.anchor+offset] = true
	return cells

static func occupied_cells(build: Dictionary, exclude_id = -1) -> Dictionary:
	var cells := {}
	var positions: Dictionary = build.get("positions",{})
	for entry in positions:
		if Items.same_entry(entry,exclude_id) or entry not in build.equipped: continue
		for offset in shape_of(entry): cells[positions[entry]+offset] = entry
	return cells

static func fits(entry, anchor: Vector2i, usable: Dictionary, occupied: Dictionary) -> bool:
	for offset in shape_of(entry):
		var cell: Vector2i = anchor+offset
		if cell.x < 0 or cell.y < 0 or cell.x >= MAX_GRID_SIZE.x or cell.y >= MAX_GRID_SIZE.y: return false
		if not usable.has(cell) or occupied.has(cell): return false
	return true

static func carried_guns(build: Dictionary) -> Array:
	var positions: Dictionary = build.get("positions",{})
	# 読み順のキー（y優先→x）を作って並べ替える。グリッドの横幅は最大6なので y*100+x で衝突しない。
	var order: Array = []
	for entry in build.equipped:
		if not Items.is_gun(entry) or not positions.has(entry): continue
		var pos: Vector2i = positions[entry]
		order.append([pos.y*100+pos.x, Items.gun_id(entry)])
	order.sort_custom(func(a,b): return a[0] < b[0])
	var result: Array = []
	for pair in order: result.append(pair[1])
	return result
