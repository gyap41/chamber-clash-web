extends RefCounted
# Shared, read-only definitions. Mutable inventory belongs to each player.
static var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/catalog.json"))
static var indexes: Dictionary = {}

static func definition(category: String, id: int) -> Dictionary:
	if not indexes.has(category):
		var index := {}
		for entry in data[category]:
			assert(entry.has("id") and not index.has(int(entry.id)), "Missing or duplicate catalog ID")
			index[int(entry.id)] = entry
		indexes[category] = index
	return indexes[category].get(id,{})
static func ids(category: String) -> Array:
	return data[category].map(func(entry): return int(entry.id))
