extends SceneTree
const Weapons = preload("res://scripts/catalog/weapon_catalog.gd")
const Relics = preload("res://scripts/catalog/relic_catalog.gd")
const Characters = preload("res://scripts/catalog/character_catalog.gd")
const Match = preload("res://scripts/game/match_state.gd")
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	assert(Weapons.SUPPORTED.size() == 38 and Relics.SUPPORTED.size() == 35)
	assert(Weapons.distributable_pool().size() == 30)
	var seen := {}
	for seed_value in range(100):
		var m := Match.new(seed_value)
		for stage in range(1,10):
			m.stage = stage
			m.generate_rewards()
			for card in m.products[0]:
				assert(card.price > 0)
				if m.is_gun(card.entry): assert(Weapons.distributable(m.gun_id(card.entry)))
				else: seen[card.entry] = true
	assert(seen.size() == 35)
	for character in range(8):
		var m := Match.new(character)
		var id := Characters.start_gun(character)
		assert(id == 20+character and not Weapons.distributable(id))
		m.grant_start_weapon(0,id)
		var entry := m.gun_token(id)
		assert(m.builds[0].owned == [entry] and m.gold[0] == 12)
		assert(m.place(0,entry,Vector2i.ZERO))
		assert(m.sale_value(0,entry) == 0)
		m._set_products(0,[entry])
		assert(not m.purchase(0,m.products[0][0].id))
		assert(m.gold[0] == 12)
	var game = load("res://scenes/game/main.tscn").instantiate()
	root.add_child(game)
	preload("res://tests/helpers/battle.gd").passive_opponents(game)
	game.set_physics_process(false)
	for entry in ["gun:28","gun:29"]+range(20,35):
		game.new_match(77)
		var m = game.match_state
		m._set_products(0,[entry])
		var price: int = m.products[0][0].price
		assert(game.preparation.claim(m.products[0][0].id))
		assert(m.gold[0] == 12-price)
		var acquired = m.builds[0].owned.back()
		assert(m.place(0,acquired,Vector2i.ZERO))
		game.preparation.refresh()
		game.preparation.show_detail(acquired)
		assert(m.sale_value(0,acquired) == price/2)
		assert(m.sell(0,acquired) and m.gold[0] == 12-price+price/2)
		# Free field acquisition survives the round boundary with its exact ID.
		preload("res://tests/helpers/battle.gd").start(game)
		var p = game.players[0]
		if typeof(entry) == TYPE_STRING:
			assert(not p.acquire_weapon(m.gun_id(entry)).is_empty())
		else:
			assert(p.acquire_temporary(entry))
		m.finish(0,game.players)
		if typeof(entry) != TYPE_STRING: assert(m.claim_temporary(0))
		var owned: Array = m.builds[0].owned
		var field_entry = owned.filter(func(item): return item == entry if typeof(entry) == TYPE_STRING else m.is_relic(item) and m.relic_id(item) == entry)[0]
		assert(m.sale_value(0,field_entry) == 0 and m.builds[0].acquisitions[field_entry].source == "field")
	# CPU starts from every exclusive starter and uses the same purchase/placement paths.
	for character in range(8):
		game.players[1].set_character(character)
		game.new_match(character)
		game.match_state._set_products(1,[20,24,34,"gun:28","gun:29"])
		game.preparation.auto_prepare(1)
		assert(game.match_state.gold[1] >= 0 and game.match_state.ready[1])
		assert(20+character in game.match_state.carried_guns(1))
	print("PASS: 35-relic pool coverage, exclusive free starters, all new purchase/placement/sale/field carry paths, CPU starters")
	game.queue_free()
	quit()

