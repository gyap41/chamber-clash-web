extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func prepare(game) -> void:
	for i in range(2):
		game.preparation.auto_prepare(i)
	game.launch_round()
	assert(game.phase == "play")
func end_round(game, winner: int) -> void:
	for p in game.players: p.state.pos = Vector2(560,420)
	if winner >= 0: game.players[1-winner].state.hp = 0
	else: game.remaining = 0
	game._physics_process(.001)
	assert(game.phase == "result")
func run() -> void:
	var game = load("res://scenes/game/main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	for sequence in [[0,0,0,0,0],[0,1,0,1,0,1,0,1,0]]:
		game.new_match(902)
		for round_index in range(sequence.size()):
			prepare(game)
			assert(game.match_state.stage == round_index+1)
			for i in range(2):
				var p = game.players[i]
				assert(game.match_state.gold[i] >= 0)
				assert(p.relic_capacity == game.match_state.capacity(i) and p.relic_capacity <= 24)
				assert(p.state.hp == p.state.max_hp and p.state.pulses == p.initial_pulses)
				assert(p.inventory.size() >= 1 and p.inventory.size() <= 8 and p.weapon().mode == 0)
			var money: Array = game.match_state.gold.duplicate()
			var stock: Array = game.match_state.products.duplicate(true)
			var count: Array = game.match_state.purchase_counts.duplicate()
			var before: Array = game.match_state.previous.duplicate(true)
			game.players[0].acquire_temporary(game.match_state.generator.candidates([],game.match_state.Items.relic_ids(before[0].owned))[0])
			end_round(game,-1)
			game.reset_round()
			assert(game.phase == "play" and game.match_state.previous == before)
			assert(game.players[0].temporary_relic == -1)
			assert(game.match_state.gold == money and game.match_state.products == stock and game.match_state.purchase_counts == count)
			end_round(game,sequence[round_index])
			var scores: Array = game.scores.duplicate()
			game.match_state.finish(sequence[round_index],game.players)
			assert(game.scores == scores)
			if round_index < sequence.size()-1:
				assert(game.match_state.gold == [money[0]+game.match_state.Shop.income(round_index+2),money[1]+game.match_state.Shop.income(round_index+2)])
				game.reset_round()
				assert(game.phase == "prepare")
		assert(game.scores == [5,sequence.size()-5])
		assert(game.match_state.builds[0].owned == [game.match_state.gun_token(0)]) # P8z：マッチが終わると所持庫は初期武器1つだけに戻る
		assert(game.match_state.gold == [0,0] and game.match_state.products == [[],[]] and game.match_state.temporary == [-1,-1])
		game.reset_round()
		assert(game.match_state.gold == [12,12] and game.match_state.capacity() == 8)
		assert(game.scores == [0,0] and game.match_state.stage == 1 and game.match_state.purchase_counts == [0,0])
	# Title -> character -> CPU preparation -> three played rounds (accelerated clock).
	game.queue_free()
	var title = load("res://scenes/ui/title.tscn").instantiate()
	root.add_child(title)
	title.get_node("Panel/Content/Start").pressed.emit()
	var select = root.get_children().filter(func(n): return n.get_script() != null and n.get_script().resource_path.ends_with("character_select.gd"))[0]
	select.select_character(0)
	game = root.get_children().filter(func(n): return n.get_script() != null and n.get_script().resource_path.ends_with("main.gd") and not n.is_queued_for_deletion())[0]
	game.set_physics_process(false)
	for n in range(5):
		# P8z：主力選択の代わりに、所持庫のものを置けるだけグリッドへ置く。
		for entry in game.match_state.builds[0].owned.duplicate():
			if entry not in game.match_state.builds[0].equipped: game.match_state.place(0,entry,game.match_state.auto_place(0,entry))
		game.preparation.ready_shop()
		assert(game.phase == "play" and game.players[1].is_cpu)
		for tick in range(30): game._physics_process(1.0/60)
		end_round(game,1)
		if n < 4: game.reset_round()
	assert(game.scores == [0,5])
	print("PASS: 5-0, 5-4, draws, equal rewards, growth, reset, title CPU integration")
	game.queue_free()
	quit()
