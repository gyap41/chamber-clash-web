extends RefCounted
const Catalog = preload("res://scripts/catalog/game_catalog.gd")
const AtlasRegions = preload("res://scripts/visuals/atlas_regions.gd")
const SHEET = preload("res://assets/characters/fighters.png")
const Rig = preload("res://scripts/visuals/character_rig.gd")
static var textures: Dictionary = {}
static func definition(id: int) -> Dictionary:
	return Catalog.definition("characters",id)
static func count() -> int:
	return Catalog.data.characters.size()
# characters[].gunが無料初期武器。専用ID20〜27は通常抽選から除外する。
static func start_gun(id: int) -> int:
	return int(definition(id).get("gun", 0))

# The character sheet has four columns and two rows.
static func art(id: int) -> AtlasTexture:
	if not textures.has(id):
		if id == 0:
			var rina := Rig.RinaDirections.texture("front")
			textures[id] = AtlasRegions.region(rina,Rect2(8,8,240,240))
		else:
			var portrait := Rig.texture(id,"front")
			textures[id] = AtlasRegions.region(portrait,Rect2(8,8,240,240))
	return textures[id]

static func ids() -> Array:
	return Catalog.ids("characters")
