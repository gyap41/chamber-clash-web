extends RefCounted
# Explicit expanded fixtures for geometry/combat tests; economy tests buy patches.
static func rectangle(m, i: int = 0) -> void:
	m.builds[i]["bag_expansions"] = [{"shape":"square","anchor":Vector2i(0,2)},{"shape":"square","anchor":Vector2i(2,2)}]
	m.expansion_bought[i] = false
	m.gold[i] = 100
