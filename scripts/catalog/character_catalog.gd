extends RefCounted
const Catalog = preload("res://scripts/catalog/game_catalog.gd")
const AtlasRegions = preload("res://scripts/visuals/atlas_regions.gd")
const SHEET = preload("res://assets/characters/fighters.png")
static var textures: Dictionary = {}
static func definition(id: int) -> Dictionary:
	return Catalog.data.characters[id]
static func count() -> int:
	return Catalog.data.characters.size()
# P8z：主力選択とサイドアームの自動付与を廃止したため、マッチ開始時に武器を渡す唯一の経路が
# キャラクターになった。data/catalog.jsonのcharacters[].gunがその初期武器（役割と名前から素直に
# 対応させた仮値・playtest調整前提）。将来はここへ「そのキャラ専用の武器」を割り当てる予定が
# あり、その場合は武器側に "exclusive": true を付けて配布プールから外す
# （scripts/catalog/weapon_catalog.gd の distributable() 参照）。
static func start_gun(id: int) -> int:
	return int(definition(id).get("gun", 0))

# The character sheet has four columns and two rows.
static func art(id: int) -> AtlasTexture:
	if not textures.has(id):
		textures[id] = AtlasRegions.grid_cell(SHEET, Vector2i(4, 2), int(definition(id).cell))
	return textures[id]
