extends RefCounted
# Prototype prices: rationale and draw weights in PURCHASE_ECONOMY_PROPOSAL.md.
const WEAPON_PRICES := [3,5,8,5,3,5,8,5,12,14,14,5,5,8,5,16,5,8,5,8]
const RELIC_PRICES := [6,7,8,9,6,5,6,4,5,4,4,4,7,5,4,5,6,5,2,2]
const MOD_PRICE := 6
const REFRESH_PRICE := 2
const INITIAL_GOLD := 12
const WIN_TARGET := 5
static func income(preparation: int) -> int:
	return 8 if preparation <= 3 else (10 if preparation <= 6 else 12)
static func price(entry) -> int:
	if typeof(entry) == TYPE_INT: return RELIC_PRICES[entry] if entry >= 0 and entry < 20 else -1
	if str(entry).begins_with("gun:"):
		var id := int(str(entry).substr(4))
		return WEAPON_PRICES[id] if id >= 0 and id < 20 else -1
	return MOD_PRICE if str(entry).begins_with("mod:") else -1
