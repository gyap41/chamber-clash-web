extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var select = load("res://scenes/ui/character_select.tscn").instantiate()
	root.add_child(select)
	assert(select.char_turn == 0 and select.picked == [-1,-1])
	var cards: Array = select.get_node("Panel/Content/Cards").get_children()
	assert(cards.size() == 8)
	# Regression check for the reported "no portrait / cards run off screen" issue: every card
	# has a portrait icon, and clip_text+ellipsis (not an unbounded custom_minimum_size) is what
	# keeps a long note from widening the button past its fixed size. 4 columns at this fixed
	# width comfortably fit the 1120px-wide screen (245*4 + 3*8px separation = 1004px).
	for card in cards:
		assert(card.icon is AtlasTexture)
		assert(card.clip_text == true)
		assert(card.custom_minimum_size == Vector2(245,150))

	assert(select.cpu_mode and not select.get_node("Panel/Content/ModeRow").visible)
	select.set_mode(false)
	assert(select.cpu_mode) # obsolete callers cannot enable local mode
	select.select_character(3)
	assert(root.get_child_count() == 1)
	var cpu_game = root.get_child(0)
	assert(cpu_game.players[0].char_id == 3 and not cpu_game.players[0].is_cpu)
	assert(cpu_game.players[1].char_id != 3 and cpu_game.players[1].is_cpu)
	assert(cpu_game.fighters[0].max_hp == 10.0)
	# CPU対戦 also auto-completes P2's weapon draft and shop turn the instant P1 finishes
	# theirs — P2/CPU never gets an actual turn in either screen (legacy's selectGun()/
	# readyShop() mode==='cpu' branches). Drive P1 through both to confirm this end-to-end.
	cpu_game.set_physics_process(false)
	# P8z：主力選択が廃止され、キャラクターの初期武器が所持庫へ入る。装備は自分でグリッドへ
	# 置くまで成立しないので、準備画面に入った時点では両者とも丸腰。
	assert(cpu_game.phase == "prepare" and cpu_game.players[1].inventory.is_empty())
	assert(cpu_game.match_state.builds[1].owned.size() == 1)
	cpu_game.match_state._set_products(0,[18,19])
	for id in [18,19]: assert(cpu_game.preparation.claim(id))
	cpu_game.preparation.ready_shop()
	assert(cpu_game.phase == "play")
	# CPUは所持庫のものを武器優先で自動配置する。段階1は6マスしかなく、形状次第では取った
	# レリックが全部は入らないため、装備数ではなく「取り切って所持庫に入っていること」で見る。
	assert(cpu_game.match_state.builds[1].owned.size() >= 2 and cpu_game.match_state.gold[1] >= 0)
	assert(cpu_game.players[1].has_weapon()) # 武器を優先して置くので丸腰にはならない
	assert(cpu_game.preparation.shop_ready == [true,true])

	# A CPU-controlled player moves under cpu_ai.gd's decision, not physical key input: step()
	# with a non-empty ai dict ignores Input entirely (see player.gd), so this is deterministic
	# in a headless test with no real keyboard/mouse state.
	var before: Vector2 = cpu_game.players[1].state.pos # spawns 780px east of P1, so it kites in
	cpu_game._physics_process(1.0/60.0)
	assert(cpu_game.players[1].state.pos != before) # moved under AI control, no input pressed

	print("PASS: CPU mode skips P2's card/draft/shop turns entirely, auto-picks a character/weapon/purchase for P2, sets is_cpu, and the resulting match drives P2 by AI on physics tick")
	cpu_game.queue_free()
	quit()
