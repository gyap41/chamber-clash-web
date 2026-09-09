extends RefCounted
const Catalog = preload("res://scripts/catalog/game_catalog.gd")
const SUPPORTED := [0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17]
static func supported(id: int) -> bool:
	return id in SUPPORTED
static func definition(id: int) -> Dictionary:
	return Catalog.data.relics[id]
