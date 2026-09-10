extends SceneTree
# 準備画面の可読性改善（タブ分割・常設説明文のツールチップ化・所持レリック一覧の重複排除）を
# 検証する。実際のマウス操作の感触やレイアウトの見た目自体はheadlessでは検証できないため、
# ノード構造・可視性・ツールチップ設定・破棄ボタンの配線のみを確認する。
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var game = load("res://scenes/game/main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.new_match(1)
	assert(game.phase == "prepare")
	var prep = game.preparation
	var state = game.match_state

	# --- タブ：初期状態は①のみ表示、ボタン3つ、押下状態も①のみtrue ---
	var tabs = prep.get_node("Root/Panel/Content/Tabs")
	assert(tabs.get_child_count() == 3)
	var cards = prep.get_node("Root/Panel/Content/Cards")
	assert(cards.get_child_count() == 3)
	assert(prep.active_tab == 0)
	assert(cards.get_child(0).visible and not cards.get_child(1).visible and not cards.get_child(2).visible)
	assert(tabs.get_child(0).button_pressed and not tabs.get_child(1).button_pressed and not tabs.get_child(2).button_pressed)

	# --- set_tab()で表示列・タブボタンの押下状態が切り替わる ---
	prep.set_tab(1)
	assert(prep.active_tab == 1)
	assert(not cards.get_child(0).visible and cards.get_child(1).visible and not cards.get_child(2).visible)
	assert(not tabs.get_child(0).button_pressed and tabs.get_child(1).button_pressed and not tabs.get_child(2).button_pressed)
	prep.set_tab(2)
	assert(cards.get_child(2).visible and not cards.get_child(0).visible and not cards.get_child(1).visible)
	prep.set_tab(0)
	assert(cards.get_child(0).visible)

	# --- ready_shop()でのターン交代時、次のプレイヤーは①タブから開始する ---
	prep.active_tab = 2
	prep.update_tab_buttons()
	assert(state.set_main(0,state.weapons[0][0]))
	state.remaining[0] = 0 # confirm()の報酬消化条件を満たし、P1の準備完了だけを成立させる
	prep.ready_shop()
	assert(game.phase == "prepare") # P2未確定のためlaunch_round()はno-op
	assert(prep.turn == 1 and prep.active_tab == 0)

	# --- 武器候補：常設の説明Labelは撤去し、ボタンのtooltip_textへ移した ---
	var col0 = cards.get_child(0).get_child(0)
	var weapon_count: int = state.weapons[prep.turn].size()
	assert(col0.get_child_count() == 2 + weapon_count) # 見出しLabel2枚＋武器ボタンのみ（説明文なし）
	var weapon_buttons: Array = col0.get_children().filter(func(c): return c is Button)
	assert(weapon_buttons.size() == weapon_count)
	for b in weapon_buttons: assert(b.tooltip_text != "")

	# --- 報酬候補：説明・相性の長文はtooltipへ。ボタン文言には相性だけ短く残す ---
	var col1 = cards.get_child(1).get_child(0)
	var reward_buttons: Array = col1.get_children().filter(func(c): return c is Button)
	var reward_labels: Array = col1.get_children().filter(func(c): return c is Label)
	assert(reward_labels.size() == 1) # 見出しLabelのみ（候補ごとの説明Labelは撤去）
	assert(reward_buttons.size() > 0)
	for b in reward_buttons:
		assert(b.tooltip_text != "" and "相性：" in b.tooltip_text)
		assert("（" in b.text) # ボタン文言自体にも相性タグ（例：良好／汎用）を短く残す

	# --- レリック配置：所持レリック全部の重複説明リストを撤去。未装備分のみ、
	#     チップ＋×（所持庫から完全放棄）ボタンの1行として控えに並べる ---
	state.builds[prep.turn].owned = [0,1,4]
	assert(state.place(prep.turn,4,state.auto_place(prep.turn,4))) # 4だけ装備してグリッドに乗せる
	prep.refresh()
	var col2 = cards.get_child(2).get_child(0)
	var tray_list = col2.get_children().back() # HFlowContainer（最後に追加される）
	assert(tray_list.get_child_count() == 2) # 未装備の0,1のみ（4は装備済みでグリッド側に表示）
	for row in tray_list.get_children():
		assert(row.get_child_count() == 2)
		assert(row.get_child(0).tooltip_text != "") # チップ側の説明はツールチップに残る
		assert(row.get_child(1).text == "×")

	# ×ボタンは discard() に配線されており、装備の着脱（toggle）とは別に所持庫から完全に外す
	var target_row = tray_list.get_children()[0]
	var target_id: int = target_row.get_child(0).relic_id
	target_row.get_child(1).pressed.emit()
	assert(target_id not in state.builds[prep.turn].owned)

	print("PASS: preparation tabs (visibility/button state, per-turn reset), weapon/reward long text moved to tooltips, relic tray dedup with wired discard button")
	game.queue_free()
	quit()
