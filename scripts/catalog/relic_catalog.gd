extends RefCounted
const Catalog = preload("res://scripts/catalog/game_catalog.gd")
const SUPPORTED := [0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19]
static func stackable(id: int) -> bool:
	return supported(id) and definition(id).get("stackable",false)
static func additive_bonus(ids: Array, stat: String) -> float:
	var bonus := 0.0
	for id in ids:
		if supported(id): bonus += float(definition(id).get(stat,0.0))
	return bonus
static func supported(id: int) -> bool:
	return id in SUPPORTED
static func definition(id: int) -> Dictionary:
	return Catalog.data.relics[id]
