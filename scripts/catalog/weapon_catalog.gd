extends RefCounted
# Shared definitions; ammunition and mode live exclusively in Player inventory.
const SUPPORTED := [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37]
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
		var art_id := int(definition(id).get("art_id",id))
		var columns := 4 if art_id < 16 else 2
		var index := art_id if art_id < 16 else art_id - 16
		textures[id] = AtlasRegions.grid_cell(BASE_SHEET if art_id < 16 else EXTRA_SHEET, Vector2i(columns, columns), index)
	return textures[id]

# 初期専用ID20〜27はexclusive指定。ショップ・フィールドの抽選はこのプールを共用する。
static func distributable(id: int) -> bool:
	return supported(id) and not bool(definition(id).get("exclusive", false))
static func distributable_pool() -> Array:
	return SUPPORTED.filter(func(id): return distributable(id))
static func rarity_pool(rarity: String) -> Array:
	return distributable_pool().filter(func(id): return definition(id).rarity == rarity)

# legacy-web/dist/data.js RARITIES (not included in catalog.json). Shared by the field-pickup
# frame color (scripts/world/pickup.gd, P7 宝箱演出) and the acquire-burst color
# (scripts/world/supplies.gd) so both stay in sync with a single source of truth.
const RARITY_COLORS := {"C":"#a7c5df","B":"#79e1c5","A":"#d2a0ff","S":"#ffdb78"}
static func rarity_color(id: int) -> Color:
	return Color(RARITY_COLORS[definition(id).rarity])

# P5 weapon modification branches: each moddable gun's catalog entry carries an optional
# "mods" array of {key,name,desc,<stat overrides...>}. Overrides replace fields on a
# *duplicated* definition dict (see apply_mod) so the shared catalog entry itself is never
# mutated — "所持定義を共有カタログへ書き戻さない".
static func mods_for(id: int) -> Array:
	return Catalog.data.guns[id].get("mods", [])
static func moddable(id: int) -> bool:
	return not mods_for(id).is_empty()
static func mod_definition(id: int, key: String) -> Dictionary:
	for mod in mods_for(id):
		if mod.key == key: return mod
	return {}
static func apply_mod(base: Dictionary, id: int, key: String) -> Dictionary:
	var mod := mod_definition(id, key)
	if mod.is_empty(): return base
	var merged := base.duplicate()
	for k in mod:
		if k == "key" or k == "name" or k == "desc": continue
		merged[k] = mod[k]
	merged["mod_key"] = key
	merged["mod_name"] = mod.name
	return merged
# The definition actually in effect for a specific weapon instance: base catalog stats with
# the active branch's overrides applied, or the untouched base definition when mod_key is
# empty/unknown. Callers that own a live weapon instance should prefer Player.resolved_
# definition()/Player.definition() below, which look the active branch up automatically.
static func resolved_definition(id: int, mod_key: String = "") -> Dictionary:
	if mod_key == "": return definition(id)
	return apply_mod(definition(id), id, mod_key)
static func mod_token(id: int, key: String) -> String:
	return "mod:%d:%s" % [id, key]
static func parse_mod_token(token: String) -> Dictionary:
	if not token.begins_with("mod:"): return {}
	var parts := token.split(":")
	if parts.size() != 3 or not parts[1].is_valid_int(): return {}
	return {"weapon_id": int(parts[1]), "mod_key": parts[2]}
