extends SceneTree

const Weapons = preload("res://scripts/catalog/weapon_catalog.gd")
const Characters = preload("res://scripts/catalog/character_catalog.gd")

func _initialize() -> void:
	# Separate players/repeated pickups must never share mutable ammunition.
	var first := Weapons.new_inventory_entry(0)
	var second := Weapons.new_inventory_entry(0)
	first.clip = 0
	first.reserve = 0
	first.mode = 1
	assert(second.clip == Weapons.definition(0).mag)
	assert(second.reserve == Weapons.definition(0).stock and second.mode == 0)
	assert(Weapons.new_inventory_entry(0) == second)

	# Non-square character sheets and the second weapon sheet use distinct grids.
	for id in range(Characters.count()):
		var portrait := Characters.art(id)
		var cell_size := portrait.atlas.get_size() / Vector2(4, 2)
		var cell := int(Characters.definition(id).cell)
		assert(portrait.region == Rect2(Vector2(cell % 4, floori(float(cell) / 4)) * cell_size, cell_size))
		assert(Characters.art(id) == portrait and portrait.filter_clip)
	for id in Weapons.SUPPORTED:
		var art := Weapons.art(id)
		var art_id := int(Weapons.definition(id).get("art_id",id))
		var columns := 4 if art_id < 16 else 2
		var cell_size := art.atlas.get_size() / columns
		var index: int = art_id if art_id < 16 else art_id - 16
		assert(art.region == Rect2(Vector2(index % columns, floori(float(index) / columns)) * cell_size, cell_size))
		assert(Weapons.art(id) == art and art.filter_clip)
	print("PASS: independent inventory and cached character/weapon atlas regions")
	quit()
