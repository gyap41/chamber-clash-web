extends RefCounted
const Grid = preload("res://scripts/game/build_grid.gd")
const Items = preload("res://scripts/game/item_identity.gd")
const Inventory = preload("res://scripts/game/exploration_inventory.gd")
const Weapons = preload("res://scripts/catalog/weapon_catalog.gd")
# Weapon tokens are stable within a run; duplicate weapon catalog IDs are rejected.
# Reserve weapon timers are frozen, not completed, while the weapon is absent.
static func draft(live):
	var copy := Inventory.new(live.seed_value)
	copy.builds = live.builds.duplicate(true)
	copy.editing = true
	return copy
static func validate(live, candidate: Dictionary) -> bool:
	if not candidate.get("positions") is Dictionary or not candidate.get("equipped") is Array: return false
	var original: Dictionary = live.builds[0]
	var fixed := candidate.duplicate(true)
	fixed.equipped = original.equipped
	fixed.positions = original.positions
	if fixed != original: return false
	if candidate.positions.size() != candidate.equipped.size(): return false
	var seen := {}
	var occupied := {}
	for entry in candidate.equipped:
		if entry not in original.owned or seen.has(entry) or not candidate.positions.get(entry) is Vector2i: return false
		var anchor: Vector2i = candidate.positions[entry]
		if not Grid.fits(entry,anchor,live.usable_cells(0),occupied): return false
		seen[entry] = true
		for offset in Grid.shape_of(entry): occupied[anchor+offset] = entry
	return Grid.carried_guns(candidate).size() <= Grid.MAX_CARRIED_WEAPONS and candidate.owned.size()-candidate.equipped.size() <= Grid.RESERVE_CAPACITY
static func capture(player, bank: Dictionary) -> void:
	for weapon in player.inventory:
		var token := Items.gun_token(weapon.id)
		if not bank.has(token): bank[token] = {"shot":0.0,"reload":0.0,"empty":false}
		bank[token].weapon = weapon.duplicate(true)
	if player.has_weapon():
		var record: Dictionary = bank[Items.gun_token(player.weapon().id)]
		record.shot = player.state.shot
		record.reload = player.state.reload
		record.empty = player.state.reload_started_empty
static func restore_active(player, bank: Dictionary) -> void:
	player.state.reload = 0.0
	player.state.reload_slot = -1
	player.state.reload_started_empty = false
	if not player.has_weapon(): return
	var token := Items.gun_token(player.weapon().id)
	if not bank.has(token): return
	var record: Dictionary = bank[token]
	player.state.shot = maxf(player.state.shot,record.shot)
	player.state.reload = record.reload
	player.state.reload_started_empty = record.empty
	if record.reload > 0:
		player.state.reload_slot = player.weapon().id
		player.reload_visual_token += 1
		player.reload_visual_active = true
		player.reload_visual_weapon = player.weapon().id
		player.reload_visual_duration = record.reload
		player.emit_weapon_event("reload_start",player.weapon().id)
static func apply(player, live, candidate: Dictionary, bank: Dictionary) -> bool:
	if live.ended or not validate(live,candidate): return false
	capture(player,bank)
	var active: int = player.weapon().id if player.has_weapon() else -1
	var carried := Grid.carried_guns(candidate)
	var weapons: Array = []
	for id in carried:
		var token := Items.gun_token(id)
		if not bank.has(token):
			# First allocation only; modifiers never grant fresh ammunition on re-equip.
			bank[token] = {"weapon":Weapons.new_inventory_entry(id),"shot":0.0,"reload":0.0,"empty":false}
		weapons.append(bank[token].weapon.duplicate(true))
	player.cancel_reload_visual()
	live.builds[0] = candidate.duplicate(true)
	player.apply_build(live.builds[0],live.capacity(0),false,live.usable_cells(0))
	player.inventory = weapons
	player.state.gun = maxi(0,carried.find(active))
	restore_active(player,bank)
	player.update_weapon_art()
	player.sync_visual()
	return true
