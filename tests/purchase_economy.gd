extends SceneTree
const Match = preload("res://scripts/game/match_state.gd")
func _initialize() -> void:
	var m = Match.new(21)
	assert(m.gold == [12,12] and m.capacity() == 8)
	m._set_products(0,[18,18,"gun:1"])
	var card: Dictionary = m.products[0][0]
	m.gold[0] = 1
	var before: Array = m.builds.duplicate(true)
	assert(not m.purchase(0,card.id) and m.gold[0] == 1 and m.builds == before and not card.sold)
	m.gold[0] = 12
	assert(m.purchase(0,card.id))
	var first = m.builds[0].owned.back()
	before = m.builds.duplicate(true)
	assert(not m.purchase(0,card.id) and m.gold[0] == 10 and m.builds == before)
	assert(m.purchase(0,m.products[0][1].id))
	var second = m.builds[0].owned.back()
	assert(first != second and m.relic_id(first) == m.relic_id(second))
	assert(m.place(0,first,Vector2i(0,0)) and m.place(0,second,Vector2i(1,0)))
	assert(m.equipped_relics(0) == [18,18])
	assert(m.sell(0,first) and m.gold[0] == 9 and second in m.builds[0].owned)
	assert(not m.sell(0,first) and m.gold[0] == 9)
	assert(m.sell(0,"gun:0") and m.gold[0] == 9)
	assert(m.purchase(0,m.products[0][2].id) and m.place(0,"gun:1",Vector2i(2,0)))
	m.gold[0] = 10
	m.sync_mod_product(0)
	var mod: Dictionary = m.products[0].back()
	assert(m.purchase(0,mod.id) and m.builds[0].mods.has(1))
	assert(m.sell(0,"gun:1") and m.gold[0] == 6 and m.builds[0].mods.is_empty())
	m._set_products(0,["gun:1"])
	assert(m.purchase(0,m.products[0][0].id) and m.builds[0].mods.is_empty())
	m.temporary[0] = 19
	m.gold[0] = 10
	var old_id: String = m.products[0][0].id
	assert(m.refresh_shop(0) and m.gold[0] == 8 and m.temporary[0] == 19)
	before = m.builds.duplicate(true)
	assert(not m.refresh_shop(0) and not m.purchase(0,old_id) and m.gold[0] == 8 and m.builds == before)
	assert(m.claim_temporary(0) and m.gold[0] == 8 and not m.claim_temporary(0))
	assert(m.sale_value(0,m.builds[0].owned.back()) == 0)
	while not m.reserve_full(0): m._acquire(0,18,"field",0,"")
	m._set_products(0,[19])
	before = m.builds.duplicate(true)
	assert(not m.purchase(0,m.products[0][0].id) and m.gold[0] == 8 and m.builds == before)
	assert(m.confirm(0) and not m.purchase(0,m.products[0][0].id))
	print("PASS: atomic insufficient/full/double purchase, instance sale, free value, mod removal/rebuy, stale cards, refresh and free claim")
	quit()
