extends RefCounted
# Inventory identity is distinct from the catalog ID. Legacy integer relics remain
# readable while builds migrate; combat receives catalog IDs at its boundary.
const RELIC_PREFIX := "relic:"
static func relic_token(catalog_id: int, serial: int) -> String:
	return "relic:%d:%d" % [catalog_id,serial]
static func is_relic(entry) -> bool:
	if typeof(entry) == TYPE_INT: return entry >= 0
	if typeof(entry) != TYPE_STRING: return false
	var parts: PackedStringArray = entry.split(":")
	return parts.size() == 3 and parts[0] == "relic" and parts[1].is_valid_int() and parts[2].is_valid_int() and int(parts[1]) >= 0 and int(parts[2]) >= 0
static func relic_id(entry) -> int:
	if not is_relic(entry): return -1
	return entry if typeof(entry) == TYPE_INT else int(entry.split(":")[1])
static func relic_ids(entries: Array) -> Array:
	return entries.filter(is_relic).map(relic_id)
