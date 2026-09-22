extends RefCounted
# Commerce policy over the inventory's state. No retained owner or duplicate state.
const Shop = preload("res://scripts/catalog/shop_catalog.gd")
const Expansions = preload("res://scripts/catalog/bag_expansions.gd")
const Weapons = preload("res://scripts/catalog/weapon_catalog.gd")
const Relics = preload("res://scripts/catalog/relic_catalog.gd")
const BuildGrid = preload("res://scripts/game/build_grid.gd")
const MAX_GRID_SIZE = BuildGrid.MAX_GRID_SIZE
static func expansion_pending(inventory,i: int) -> bool:
	return inventory.valid_slot(i) and inventory.can_trade(i) and not inventory.expansion_bought[i] and inventory.capacity(i) <= 20
static func expansion_purchase_reason(inventory,i: int, shape: String) -> String:
	if not inventory.valid_slot(i) or not Expansions.SHAPES.has(shape): return "無効な拡張"
	if not inventory.can_trade(i): return "現在は購入・売却できません"
	if inventory.expansion_bought[i]: return "この準備では購入済み"
	if inventory.capacity(i)+Expansions.SHAPES[shape].size() > BuildGrid.MAX_AREA: return "上限24マス（残り%d）" % (BuildGrid.MAX_AREA-inventory.capacity(i))
	if inventory.gold[i] < Expansions.SHAPES[shape].size(): return "資金不足（必要%dG）" % Expansions.SHAPES[shape].size()
	return ""
static func expansion_offer_reason(inventory,i: int, shape: String) -> String:
	var reason = inventory.expansion_purchase_reason(i,shape)
	if not reason.is_empty(): return reason
	for y in range(MAX_GRID_SIZE.y):
		for x in range(MAX_GRID_SIZE.x):
			if inventory.expansion_reason(i,shape,Vector2i(x,y)).is_empty(): return ""
	return "この形を置ける場所なし"
static func expansion_reason(inventory,i: int, shape: String, anchor: Vector2i) -> String:
	var reason = inventory.expansion_purchase_reason(i,shape)
	if not reason.is_empty(): return reason
	var usable = inventory.usable_cells(i)
	var connected = false
	for offset in Expansions.SHAPES[shape]:
		var cell: Vector2i = anchor+offset
		if cell.x < 0 or cell.y < 0 or cell.x >= MAX_GRID_SIZE.x or cell.y >= MAX_GRID_SIZE.y: return "グリッドの外"
		if usable.has(cell): return "開放済みマスと重複"
		for direction in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			if usable.has(cell+direction): connected = true
	return "" if connected else "バッグに辺で接続してください"
static func place_expansion(inventory,i: int, shape: String, anchor: Vector2i) -> bool:
	if not inventory.expansion_reason(i,shape,anchor).is_empty(): return false
	inventory.gold[i] -= Expansions.SHAPES[shape].size()
	inventory.expansion_bought[i] = true
	if not inventory.builds[i].has("bag_expansions"): inventory.builds[i]["bag_expansions"] = []
	inventory.builds[i].bag_expansions.append({"shape":shape,"anchor":anchor})
	return true
static func auto_expand(inventory,i: int) -> bool:
	if not inventory.expansion_pending(i): return false
	for shape in Expansions.SHAPES:
		for y in range(MAX_GRID_SIZE.y):
			for x in range(MAX_GRID_SIZE.x):
				if inventory.place_expansion(i,shape,Vector2i(x,y)): return true
	return false
static func _base_products(inventory) -> Array:
	var result: Array = []
	for slot in range(2):
		var roll: int = inventory.generator.rng.randi_range(0,99)
		var rarity: String
		if inventory.shop_stage() < 3: rarity = "C" if roll < 35 else ("B" if roll < 75 else "A")
		else: rarity = "C" if roll < 25 else ("B" if roll < 60 else ("A" if roll < 85 else "S"))
		var pool: Array = Weapons.rarity_pool(rarity)
		result.append(inventory.gun_token(pool[inventory.generator.rng.randi_range(0,pool.size()-1)]))
	for slot in range(3): result.append(Relics.SUPPORTED[inventory.generator.rng.randi_range(0,Relics.SUPPORTED.size()-1)])
	return result
static func _card(inventory,entry) -> Dictionary:
	var result = {"id":"card:%d" % inventory.next_card_id,"entry":entry,"price":Shop.price(entry),"sold":false}
	inventory.next_card_id += 1
	return result
static func _set_products(inventory,i: int, base: Array) -> void:
	inventory.products[i] = []
	for entry in base: inventory.products[i].append(inventory._card(entry))
	inventory._sync_rewards(i)
	inventory.sync_mod_product(i)
static func _sync_rewards(inventory,i: int) -> void:
	inventory.rewards[i] = inventory.products[i].map(func(card): return card.entry)
static func generate_rewards(inventory) -> void:
	var base = inventory._base_products()
	for i in range(inventory.builds.size()): inventory._set_products(i,base)
static func sync_mod_product(inventory,i: int) -> void:
	if not inventory.can_trade(i): return
	# Once offered, retain even an unavailable mod: moving equipment is not a free reroll.
	var cards: Array = inventory.products[i].filter(func(card): return str(card.entry).begins_with("mod:"))
	if not cards.is_empty(): return
	var candidates = inventory.mod_candidates(i)
	if not candidates.is_empty(): inventory.products[i].append(inventory._card(candidates[inventory.generator.rng.randi_range(0,candidates.size()-1)]))
	inventory._sync_rewards(i)
static func refresh_shop(inventory,i: int) -> bool:
	if not inventory.can_trade(i) or inventory.refreshed[i] or inventory.gold[i] < Shop.REFRESH_PRICE: return false
	inventory.gold[i] -= Shop.REFRESH_PRICE
	inventory.refreshed[i] = true
	inventory._set_products(i,inventory._base_products())
	return true
static func product(inventory,i: int, card_id: String) -> Dictionary:
	if not inventory.valid_slot(i): return {}
	for card in inventory.products[i]:
		if card.id == card_id: return card
	return {}
static func mod_candidates(inventory,i: int) -> Array:
	var result: Array = []
	for main_id in inventory.carried_guns(i):
		if not Weapons.moddable(main_id) or inventory.builds[i].get("mods",{}).has(main_id): continue
		for mod in Weapons.mods_for(main_id): result.append(Weapons.mod_token(main_id,mod.key))
	return result
static func acquisition_reason(inventory,i: int, entry) -> String:
	if not inventory.valid_slot(i): return "無効"
	if not inventory.can_trade(i): return "現在は購入・売却できません"
	return inventory.storage_reason(i,entry)
static func purchase_reason(inventory,i: int, card_id: String) -> String:
	var card = inventory.product(i,card_id)
	if card.is_empty(): return "候補外"
	if card.price < 0 or (inventory.is_gun(card.entry) and not Weapons.distributable(inventory.gun_id(card.entry))): return "非売品"
	if card.sold: return "売り切れ"
	var why = inventory.acquisition_reason(i,card.entry)
	if not why.is_empty(): return why
	if inventory.gold[i] < card.price: return "資金不足"
	return ""
static func purchase(inventory,i: int, card_id: String) -> bool:
	if not inventory.purchase_reason(i,card_id).is_empty(): return false
	var card = inventory.product(i,card_id)
	# All validation precedes this synchronous transaction; no signal/await in between.
	inventory.gold[i] -= card.price
	card.sold = true
	inventory._acquire(i,card.entry,"purchase",card.price,card.id)
	inventory.purchase_counts[i] += 1
	return true
static func temporary_reason(inventory,i: int) -> String:
	if not inventory.valid_slot(i) or inventory.temporary[i] < 0: return "持ち帰り候補なし"
	return inventory.acquisition_reason(i,inventory.temporary[i])
static func claim_temporary(inventory,i: int) -> bool:
	if not inventory.temporary_reason(i).is_empty(): return false
	inventory._acquire(i,inventory.temporary[i],"field",0,"")
	inventory.temporary[i] = -1
	return true
static func reason(inventory,i: int, entry) -> String:
	if not inventory.valid_slot(i): return "無効"
	for card in inventory.products[i]:
		if typeof(card.entry) == typeof(entry) and card.entry == entry: return inventory.purchase_reason(i,card.id)
	return "候補外"
static func claim(inventory,i: int, entry) -> bool:
	if not inventory.valid_slot(i): return false
	for card in inventory.products[i]:
		if typeof(card.entry) == typeof(entry) and card.entry == entry: return inventory.purchase(i,card.id)
	return false
static func mod_reason(inventory,i: int, token: String) -> String:
	if not inventory.can_trade(i): return "現在は購入・売却できません"
	var parsed = Weapons.parse_mod_token(token)
	if parsed.is_empty(): return "無効"
	if inventory.gun_token(parsed.weapon_id) not in inventory.builds[i].equipped: return "携行していない"
	if inventory.builds[i].get("mods",{}).has(parsed.weapon_id): return "改造済み"
	return ""
static func sale_value(inventory,i: int, entry) -> int:
	return int(inventory.builds[i].get("acquisitions",{}).get(entry,{}).get("paid",0)/2)
static func sell(inventory,i: int, entry) -> bool:
	if not inventory.can_trade(i) or entry not in inventory.builds[i].owned: return false
	var value = inventory.sale_value(i,entry)
	if not inventory.discard(i,entry): return false
	inventory.gold[i] += value
	return true
