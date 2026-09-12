extends SceneTree
const Match = preload("res://scripts/game/match_state.gd")
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var game = load("res://scenes/game/main.tscn").instantiate()
	root.add_child(game)
	preload("res://tests/helpers/battle.gd").passive_opponents(game)
	game.set_physics_process(false)
	var m = game.match_state
	# Paid expansion is independent of stage, capped at 24; failures are atomic.
	for anchor in [Vector2i(4,0),Vector2i(0,2),Vector2i(2,2),Vector2i(4,2)]:
		m.gold[0] = 4
		m.expansion_bought[0] = false # next preparation fixture
		assert(m.place_expansion(0,"square",anchor) and m.gold[0] == 0)
		var old: Array = m.builds.duplicate(true)
		assert(not m.place_expansion(0,"square",anchor) and m.builds == old)
	assert(m.capacity() == 24 and m.stage == 1)
	m.gold[0] = 100
	m.expansion_bought[0] = false
	assert(not m.place_expansion(0,"square",Vector2i(0,4)) and m.capacity() == 24 and m.gold[0] == 100)
	game.new_match(32)
	m = game.match_state
	m.ready = [true,true]
	assert(game.players[0].acquire_weapon(15) != "" and not game.players[0].owns(15))
	game.players[0].temporary_relic = 18
	m.start_round()
	var stock: Array = m.products.duplicate(true)
	m.finish(-1,game.players)
	assert(m.gold == [12,12] and m.products == stock and m.builds[0].owned == ["gun:0","gun:15"] and m.temporary == [-1,-1])
	m.start_round()
	m.finish(0,game.players)
	assert(m.gold == [20,20] and "gun:15" in m.builds[0].owned and m.temporary[0] == 18)
	assert(m.builds[0].acquisitions["gun:15"] == {"source":"field","paid":0,"card_id":""})
	while not m.reserve_full(0): m._acquire(0,19,"field",0,"")
	var full: Dictionary = m.builds[0].duplicate(true)
	assert(not m.claim_temporary(0) and m.builds[0] == full and m.temporary[0] == 18)
	assert(m.sell(0,m.reserve_items(0).back()) and m.gold[0] == 20)
	assert(m.claim_temporary(0) and m.gold[0] == 20)
	m.start_round()
	m.scores = [4,4]
	game.players[0].add_gun(10)
	game.players[0].temporary_relic = 19
	m.finish(1,game.players)
	assert(m.stage == 2 and m.ended and m.gold == [0,0] and m.products == [[],[]] and m.temporary == [-1,-1])
	assert(m.builds[0].owned == ["gun:0"] and m.builds[0].next_item_serial == 0 and m.builds[0].mods.is_empty())
	assert(not m.confirm(0) and not m.refresh_shop(0) and not m.place_expansion(0,"square",Vector2i(4,0)))
	# CPU uses actual income and purchase/placement APIs over 20 seeded full matches.
	for seed_index in range(20):
		game.new_match(seed_index+100)
		m = game.match_state
		var total := 12
		for round_index in range(9):
			for i in range(2):
				var before: Array = m.builds[i].owned.duplicate()
				game.preparation.auto_prepare(i)
				assert(m.ready[i] and m.gold[i] >= 0 and m.reserve_items(i).size() <= 8 and not m.carried_guns(i).is_empty())
				var spent: int = m.capacity(i)-8
				for metadata in m.builds[i].acquisitions.values(): spent += int(metadata.paid)
				assert(m.gold[i]+spent == total)
				for entry in m.builds[i].owned:
					if entry not in before: assert(entry in m.builds[i].equipped)
				for entry in m.builds[i].equipped: assert(m.fits(i,entry,m.builds[i].positions[entry],entry))
			game.launch_round()
			m.finish(round_index%2,game.players)
			if round_index < 8:
				total += m.Shop.income(round_index+2)
				game.phase = "prepare"
		assert(m.ended and total == 94)
	game.queue_free()
	await process_frame
	print("PASS: 24-cell cap, field carry/full/free claim, draw/final boundaries, 20 seeded CPU budget and placement matches")
	quit()
