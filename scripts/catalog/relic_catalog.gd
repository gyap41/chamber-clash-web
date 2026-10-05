extends RefCounted
const Catalog = preload("res://scripts/catalog/game_catalog.gd")
const SUPPORTED := [0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34]
static func rarity(id: int) -> String:
	if id in [2,3,12,16,27,28]: return "A"
	if id in [1,4,5,6,8,9,13,14,15,17,21,23,33]: return "B"
	return "C"
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
	var data := Catalog.definition("relics",id).duplicate()
	data.rarity = rarity(id)
	return data
static func stacked_value(ids: Array, id: int, key: String) -> float:
	var relic := definition(id)
	var value := float(relic.get(key,0.0))
	if key not in relic.get("stack_stats",[]): return value
	var count := ids.count(id)
	return pow(value,count) if key.ends_with("_ratio") else value*count
static func stack_summary(id: int, count: int) -> String:
	var relic := definition(id)
	var parts := PackedStringArray()
	for key in relic.get("stack_stats",[]):
		var value := float(relic[key])
		if key.ends_with("_ratio"):
			parts.append(("弾速" if key == "heavy_ratio" else "")+"-%.1f%%" % ((1.0-pow(value,count))*100.0))
		elif key in ["hp_bonus","mag_bonus","last_bonus"]:
			parts.append("+%s%s" % [("%.2f" % (value*count)).trim_suffix("0").trim_suffix("0").trim_suffix("."),"HP" if key == "hp_bonus" else ("発" if key == "mag_bonus" else "ダメージ")])
		elif key == "size_bonus":
			parts.append("弾径+%d%%" % roundi(minf(.6,value*count)*100.0))
		else:
			parts.append(("威力" if key == "heavy_bonus" else "")+"+%d%%" % roundi(value*count*100.0))
	return " / ".join(parts)
