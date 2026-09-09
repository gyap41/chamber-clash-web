extends RefCounted
# Shared definitions; ammunition and mode live exclusively in Player inventory.
const SUPPORTED := [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19]
const Catalog = preload("res://scripts/catalog/game_catalog.gd")
const AtlasRegions = preload("res://scripts/visuals/atlas_regions.gd")
const BASE_SHEET = preload("res://assets/weapons/weapons.png")
const EXTRA_SHEET = preload("res://assets/weapons/weapons-extra.png")
static var textures: Dictionary = {}

static func definition(id: int) -> Dictionary:
	return Catalog.data.guns[id]

static func new_inventory_entry(id: int) -> Dictionary:
	var gun := definition(id)
	return {"id": id, "clip": int(gun.mag), "reserve": int(gun.stock), "mode": 0}

static func supported(id: int) -> bool:
	return id in SUPPORTED

static func art(id: int) -> AtlasTexture:
	if not textures.has(id):
		var columns := 4 if id < 16 else 2
		var index := id if id < 16 else id - 16
		textures[id] = AtlasRegions.grid_cell(BASE_SHEET if id < 16 else EXTRA_SHEET, Vector2i(columns, columns), index)
	return textures[id]

static func rarity_pool(rarity: String) -> Array:
	return SUPPORTED.filter(func(id): return definition(id).rarity == rarity)
