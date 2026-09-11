extends RefCounted
# Deterministic preparation policy. Uses the same transactions as human players.
const Weapons = preload("res://scripts/catalog/weapon_catalog.gd")
const Items = preload("res://scripts/game/item_identity.gd")
const BuildGrid = preload("res://scripts/game/build_grid.gd")

static func affinity(id, guns: Array, equipped: Array = []) -> int:
	# P5 mod tokens ("mod:<weapon_id>:<key>") aren't relics; score them like a solid-but-not-
	# best pick when they target a weapon the CPU actually carries, and never applicable
	# otherwise (a stale token for a weapon since taken off the grid — see MatchState.mod_reason).
	if typeof(id) == TYPE_STRING and not Items.is_gun(id) and not Items.is_relic(id):
		var parsed := Weapons.parse_mod_token(id)
		return 3 if not parsed.is_empty() and parsed.weapon_id in guns else 0
	if Items.is_gun(id): return 0 # 武器同士の相性は見ない（並べ替えはweapon_score側）
	id = Items.relic_id(id)
	var g := Weapons.definition(guns[0] if not guns.is_empty() else 0)
	if id == 2: return 0 if ["split","comet","gravity","boomerang","seed","bubble","clover"].any(func(tag): return g.get(tag,false)) else 4
	if id == 11: return 4 if int(g.get("bounce",0)) > 0 or (2 in equipped and affinity(2,guns) > 0) else 0
	if id == 7: return 3 if int(g.mag) <= 6 else 1
	if id == 1: return 3 if int(g.mag) <= 6 else 2
	if id == 6: return 3 if int(g.get("count",1)) > 1 else 2
	# P3 additions: only give the two relics with an obvious weapon-tag correlation (bounce
	# for 反響の種, boomerang for 帰還バッテリー) a non-default score, same simple heuristic
	# style as above; the other four (13/15/16/17) apply to any build about equally, so they
	# keep the generic fallback score of 2 rather than a fabricated preference.
	if id == 12: return 4 if int(g.get("bounce",0)) > 0 or (2 in equipped and affinity(2,guns) > 0) else 1
	if id == 14: return 4 if g.get("boomerang",false) else 1
	if id == 31: return 4 if guns.any(func(gun): return int(Weapons.definition(gun).get("bounce",0)) > 0) or (2 in equipped and affinity(2,guns) > 0) else 0
	if id == 32: return 4 if guns.any(func(gun): return ["split","clover","parcel"].any(func(tag): return Weapons.definition(gun).get(tag,false))) else 0
	if id == 33: return 4 if guns.any(func(gun): return Weapons.definition(gun).get("boomerang",false)) else 0
	if id == 30: return 3 if guns.size() > 1 else 1
	if id == 22: return 3 if int(g.mag) <= 6 else 2
	return 2
# Place owned weapons first, then buy a patch, claim the field relic and purchase
# affordable products that fit. Every mutation goes through MatchState's public API.
static func auto_prepare(state, i: int) -> void:
	var owned: Array = state.builds[i].owned.duplicate()
	var guns: Array = owned.filter(func(e): return Items.is_gun(e))
	guns.sort_custom(func(a,b): return weapon_score(Items.gun_id(a),[]) > weapon_score(Items.gun_id(b),[]))
	state.arrange(i,guns+owned.filter(func(e): return Items.is_relic(e)))
	# Reserve 4G for equipment after a patch. Grow by at most one paid patch per preparation.
	if state.stage >= 2 and state.gold[i] >= 8 and state.capacity(i) < BuildGrid.MAX_AREA:
		state.auto_expand(i)
		state.arrange(i,guns+owned.filter(func(e): return Items.is_relic(e)))
	if state.claim_temporary(i):
		var free_entry = state.builds[i].owned.back()
		state.place(i,free_entry,state.auto_place(i,free_entry))
	state.sync_mod_product(i)
	var cards: Array = state.products[i].duplicate()
	cards.sort_custom(func(a,b): return purchase_score(a,state,i) > purchase_score(b,state,i))
	for card in cards:
		if not state.purchase_reason(i,card.id).is_empty(): continue
		var is_mod: bool = str(card.entry).begins_with("mod:")
		if not is_mod and state.auto_place(i,card.entry).x < 0: continue
		if state.purchase(i,card.id) and not is_mod:
			var acquired = state.builds[i].owned.back()
			state.place(i,acquired,state.auto_place(i,acquired))
	state.sync_mod_product(i)
	for card in state.products[i]:
		if str(card.entry).begins_with("mod:"): state.purchase(i,card.id)
	state.confirm(i)
static func purchase_score(card: Dictionary, state, i: int) -> float:
	var value: int = weapon_score(Items.gun_id(card.entry),[])+2 if Items.is_gun(card.entry) else affinity(card.entry,state.carried_guns(i),state.equipped_relics(i))+2
	return float(value)/maxi(1,card.price)
static func weapon_score(id: int, relics: Array) -> int:
	var score := 0
	for relic in relics: score += affinity(relic,[id],relics)
	return score + ["C","B","A","S"].find(Weapons.definition(id).rarity)
