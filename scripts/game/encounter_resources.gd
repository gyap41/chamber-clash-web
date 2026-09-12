extends RefCounted
# Resource snapshot for a room/encounter boundary, not a save format or profile unlocks.
# Timers, hit immunity, buffered input and queued shots deliberately do not travel.
const RESOURCE_KEYS := ["hp","max_hp","pulses","gun"]
static func capture(player) -> Dictionary:
	var resources := {}
	for key in RESOURCE_KEYS: resources[key] = player.state[key]
	return {"resources":resources,"inventory":player.inventory.duplicate(true),"relics":player.relics.duplicate(),"owned_relics":player.owned_relics.duplicate(),"weapon_mods":player.weapon_mods.duplicate(true),"field_region":player.field_region.duplicate(),"field_occupied":player.field_occupied.duplicate(),"temporary_relic":player.temporary_relic,"temporary_relic_slot":player.temporary_relic_slot,"relic_capacity":player.relic_capacity}
static func restore(player, snapshot: Dictionary) -> void:
	for key in RESOURCE_KEYS: player.state[key] = snapshot.resources[key]
	for key in ["inventory","relics","owned_relics","weapon_mods","field_region","field_occupied"]:
		player.set(key,snapshot[key].duplicate(true))
	for key in ["temporary_relic","temporary_relic_slot","relic_capacity"]: player.set(key,snapshot[key])
	player.update_weapon_art()
	player.sync_visual()
