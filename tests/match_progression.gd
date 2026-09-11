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
	for sequence in [[0,0,0],[0,1,0,1,0]]:
		game.new_match(902)
		for round_index in range(sequence.size()):
			prepare(game)
			assert(game.match_state.stage == round_index+1)
			assert(game.match_state.reward_counts == [round_index,round_index])
			for i in range(2):
				var p = game.players[i]
				# P5: auto_prepare() can spend a reward pick on a weapon-mod branch instead of a
				# relic once a player's main is one of the moddable guns, so relic count can run
				# short of "2+round_index" by however many mod branches that player has claimed.
				# P8z：装備はグリッドの面積で決まるため、取った数がそのまま装備数になるとは限らない
				# （武器がマスを食い、形状によっては入らない）。報酬を取り切ったことは所持庫で見る。
				var stored: int = game.match_state.builds[i].owned.filter(func(e): return game.match_state.is_relic(e)).size()
				assert(stored == 2+round_index-game.match_state.builds[i].mods.size())
				assert(p.relics.size() <= stored)
				# P8x：容量は個数上限ではなくグリッドの面積（match_state.gdのGRID_SIZES＝
				# 3×2/4×2/4×3/4×4/4×4）に統合された。ここでは「段階が進むごとに枠が広がる」
				# という成長カーブそのものの検証が目的なので、面積の実数値を期待値に置く。
				assert(p.relic_capacity == [6,8,12,16,22][round_index])
				assert(p.state.hp == p.state.max_hp and p.state.pulses == p.initial_pulses)
				# P8z：サイドアーム＋主力の2丁固定はなくなり、携行はグリッドに置いた武器だけ。
				# auto_prepare()は武器を優先して置くので、初期武器の1丁を必ず持っている。
				assert(p.inventory.size() == 1 and p.weapon().mode == 0)
			var before: Array = game.match_state.previous.duplicate(true)
			game.players[0].acquire_temporary(game.match_state.generator.candidates([],game.match_state.Items.relic_ids(before[0].owned))[0])
			end_round(game,-1)
			game.reset_round()
			assert(game.phase == "play" and game.match_state.previous == before)
			assert(game.players[0].temporary_relic == -1)
			assert(game.match_state.reward_counts == [round_index,round_index])
			end_round(game,sequence[round_index])
			var scores: Array = game.scores.duplicate()
			game.match_state.finish(sequence[round_index],game.players)
			assert(game.scores == scores)
			if round_index < sequence.size()-1:
				game.reset_round()
				assert(game.phase == "prepare")
		assert(game.scores == [3,sequence.size()-3])
		assert(game.match_state.builds[0].owned == [game.match_state.gun_token(0)]) # P8z：マッチが終わると所持庫は初期武器1つだけに戻る
		game.reset_round()
		assert(game.scores == [0,0] and game.match_state.stage == 1 and game.match_state.reward_counts == [0,0])
	# Title -> character -> CPU preparation -> three played rounds (accelerated clock).
	game.queue_free()
	var title = load("res://scenes/ui/title.tscn").instantiate()
	root.add_child(title)
	title.get_node("Panel/Content/Start").pressed.emit()
	var select = root.get_children().filter(func(n): return n.get_script() != null and n.get_script().resource_path.ends_with("character_select.gd"))[0]
	select.select_character(0)
	game = root.get_children().filter(func(n): return n.get_script() != null and n.get_script().resource_path.ends_with("main.gd") and not n.is_queued_for_deletion())[0]
	game.set_physics_process(false)
	for n in range(3):
		# P8z：主力選択の代わりに、所持庫のものを置けるだけグリッドへ置く。
		for entry in game.match_state.builds[0].owned.duplicate():
			if entry not in game.match_state.builds[0].equipped: game.match_state.place(0,entry,game.match_state.auto_place(0,entry))
		for id in game.match_state.rewards[0]:
			if game.match_state.remaining[0] > 0: game.preparation.claim(id)
		game.preparation.ready_shop()
		assert(game.phase == "play" and game.players[1].is_cpu)
		for tick in range(30): game._physics_process(1.0/60)
		end_round(game,1)
		if n < 2: game.reset_round()
	assert(game.scores == [0,3])
	print("PASS: 3-0, 3-2, draws, equal rewards, growth, reset, title CPU integration")
	game.queue_free()
	quit()
