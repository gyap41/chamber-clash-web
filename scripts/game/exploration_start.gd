extends RefCounted
# The sole new-run factory. Future profile bonuses belong here, never at room entry.
const Inventory = preload("res://scripts/game/exploration_inventory.gd")
const Characters = preload("res://scripts/catalog/character_catalog.gd")
static func create(seed_value: int):
	var inventory = Inventory.new(seed_value)
	inventory.grant_start_weapon(0,Characters.start_gun(0))
	inventory.editing = true
	var token = inventory.gun_token(Characters.start_gun(0))
	var placed: bool = inventory.place(0,token,inventory.auto_place(0,token))
	assert(placed)
	inventory.editing = false
	return inventory
