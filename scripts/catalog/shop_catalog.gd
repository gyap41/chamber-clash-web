extends RefCounted
const Items = preload("res://scripts/game/item_identity.gd")
# Prototype prices: rationale and draw weights in PURCHASE_ECONOMY_PROPOSAL.md.
const WEAPON_PRICES := [3,5,8,5,3,5,8,5,12,14,14,5,5,8,5,16,5,8,5,8,-1,-1,-1,-1,-1,-1,-1,-1,5,8,3,3,5,5,5,8,8,14]
const RELIC_PRICES := [6,7,8,9,6,5,6,4,5,4,4,4,7,5,4,5,6,5,2,2,5,6,4,4,6,4,4,6,6,4,4,4,5,4,3]
const MOD_PRICE := 6
const REFRESH_PRICE := 2
const INITIAL_GOLD := 12
const WIN_TARGET := 5
static func income(preparation: int) -> int:
	return 8 if preparation <= 3 else (10 if preparation <= 6 else 12)
static func price(entry) -> int:
	if typeof(entry) == TYPE_INT: return RELIC_PRICES[entry] if entry >= 0 and entry < RELIC_PRICES.size() else -1
	if Items.is_gun(entry):
		var id := Items.gun_id(entry)
		return WEAPON_PRICES[id] if id >= 0 and id < WEAPON_PRICES.size() else -1
	return MOD_PRICE if str(entry).begins_with("mod:") else -1
