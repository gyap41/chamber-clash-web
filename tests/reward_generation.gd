extends SceneTree
const Match = preload("res://scripts/game/match_state.gd")
func _initialize() -> void:
	var a = Match.new(445)
	var b = Match.new(445)
	assert(a.rewards == b.rewards and a.rewards[0] == a.rewards[1]) # P8z：武器候補リスト(weapons)は主力選択とともに廃止
	for n in range(10):
		a.generate_rewards()
		b.generate_rewards()
		assert(a.rewards == b.rewards)
	# P3 added relic ids 12-17 (Relics.SUPPORTED now runs 0-17, 18 total): the "one short of the
	# full pool" / "fully owned" bounds below shift from 11/12 to 17/18 accordingly.
	assert(a.generator.candidates([17,18,19],range(17)) == [17,18,19])
	assert(a.generator.candidates([18,19],range(20)) == [18,19])
	a._set_products(0,[0,1,2])
	a._set_products(1,[0,1,2])
	assert(a.claim(0,0) and a.claim(1,0))
	assert(not a.claim(0,0) and not a.claim(0,-1))
	a.temporary = [8,-1]
	assert(a.claim_temporary(0) and a.gold == [6,6])
	assert(not a.claim(0,1) and a.reason(0,1) == "資金不足")
	assert(a.confirm(0) and not a.confirm(0) and not a.claim(0,2))
	assert(not a.toggle(0,0) and not a.discard(0,0))
	# Deterministic shared base, but independent immutable card identities and stock.
	for stage in range(1,10):
		a.stage = stage
		a.ready = [false,false]
		a.generate_rewards()
		assert(a.rewards[0] == a.rewards[1] and a.products[0][0].id != a.products[1][0].id)
		assert(a.products[0].size() == 5)
		for card in a.products[0]:
			assert(card.price > 0)
			if stage < 3 and a.is_gun(card.entry): assert(a.Weapons.definition(a.gun_id(card.entry)).rarity != "S")
	print("PASS: seeded shared stock, independent cards, affordability, optional shopping, free temporary, stage rarity gate")
	quit()
