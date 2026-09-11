extends RefCounted
const Catalog = preload("res://scripts/catalog/game_catalog.gd")
const AtlasRegions = preload("res://scripts/visuals/atlas_regions.gd")
const SHEET = preload("res://assets/characters/fighters.png")
static var textures: Dictionary = {}
static func definition(id: int) -> Dictionary:
	return Catalog.data.characters[id]
static func count() -> int:
	return Catalog.data.characters.size()
# characters[].gunが無料初期武器。専用ID20〜27は通常抽選から除外する。
static func start_gun(id: int) -> int:
	return int(definition(id).get("gun", 0))

# The character sheet has four columns and two rows.
static func art(id: int) -> AtlasTexture:
	if not textures.has(id):
		textures[id] = AtlasRegions.grid_cell(SHEET, Vector2i(4, 2), int(definition(id).cell))
	return textures[id]
