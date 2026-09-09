extends RefCounted
# Shared, read-only definitions. Mutable inventory belongs to each player.
static var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/catalog.json"))
