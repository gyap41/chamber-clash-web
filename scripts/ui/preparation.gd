extends CanvasLayer
const Weapons = preload("res://scripts/catalog/weapon_catalog.gd")
const Relics = preload("res://scripts/catalog/relic_catalog.gd")
const RelicChip = preload("res://scripts/ui/relic_chip.gd")
const RelicGridCell = preload("res://scripts/ui/relic_grid_cell.gd")
const RelicTray = preload("res://scripts/ui/relic_tray.gd")
var game
var turn := 0
var choices: Array = []
var shop_ready: Array:
	get: return game.match_state.ready
var started := 0
var scroll_turn := -1
# UI可読性改善：武器選択／報酬選択／レリック配置を同時に3列表示せず、タブで1つずつ見せる
# （常時表示の説明文をツールチップへ移す変更と合わせて、画面の文字量を大きく減らす）。
const TAB_NAMES := ["① 主力武器","② 報酬","③ レリック配置"]
var active_tab := 0
func _ready() -> void:
	$Root/Panel/Content/Ready.pressed.connect(ready_shop)
	for n in range(TAB_NAMES.size()):
		var btn := Button.new()
		btn.text = TAB_NAMES[n]
		btn.toggle_mode = true
		btn.focus_mode = Control.FOCUS_NONE
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.pressed.connect(set_tab.bind(n))
		$Root/Panel/Content/Tabs.add_child(btn)
	update_tab_buttons()
func set_tab(n: int) -> void:
	if active_tab == n: return
	active_tab = n
	update_tab_buttons()
	refresh()
func update_tab_buttons() -> void:
	for n in range($Root/Panel/Content/Tabs.get_child_count()):
		$Root/Panel/Content/Tabs.get_child(n).button_pressed = n == active_tab
func begin() -> void:
	scroll_turn = -1
	turn = 0
	active_tab = 0
	update_tab_buttons()
	started = Time.get_ticks_msec()
	choices = game.match_state.weapons[0].duplicate()
	refresh()
func select_gun(id: int) -> bool:
	if game.phase != "prepare" or not game.match_state.set_main(turn,id): return false
	game.telemetry.record("main",{"player":turn,"id":id})
	refresh()
	return true
func claim(id) -> bool:
	if game.phase != "prepare" or not game.match_state.claim(turn,id): return false
	game.telemetry.record("reward",{"player":turn,"id":id})
	refresh()
	return true
# P8 配置基盤：ドラッグ＆ドロップでの配置・移動（グリッドのマスへドロップ）。可否は
# match_state.place()＝そのマスに形状が実際に収まるかどうかだけで決まる。同じマスへ置き直す等、
# 実際には何も変わらないドロップでも一律refresh()するが、副作用はなく無害。
# P8y 取得と配置の分離：人間が装備する経路はこのplace()だけになった。位置を自動で決める
# match_state.toggle()の装備側を呼ぶ人間向けラッパー（旧toggle()）は、報酬取得時の即時装備と
# あわせて撤去してある——自動配置を使うのはauto_prepare()＝CPUだけ。
func place_relic(id: int, cell: Vector2i) -> void:
	if game.phase != "prepare": return
	if game.match_state.place(turn,id,cell): game.telemetry.record("place_relic",{"player":turn,"id":id,"cell":cell})
	refresh()
# 控え（RelicTray）へドラッグで戻したときの解除。すでに未装備のレリックを誤ってここへ落として
# もtoggle()を呼ばない（toggle()は「未装備なら装備」に倒れるため、無関係な誤装備を防ぐ）。
func unequip_relic(id: int) -> void:
	if game.phase != "prepare" or id not in game.match_state.builds[turn].equipped: return
	if game.match_state.toggle(turn,id): game.telemetry.record("unequip_relic",{"player":turn,"id":id})
	refresh()
func discard(id: int) -> void:
	if game.phase != "prepare": return
	if game.match_state.discard(turn,id): game.telemetry.record("discard",{"player":turn,"id":id})
	refresh()
func ready_shop() -> void:
	if game.phase != "prepare" or not game.match_state.confirm(turn): return
	game.telemetry.record("preparation",{"player":turn,"seconds":(Time.get_ticks_msec()-started)/1000.0,"build":game.match_state.builds[turn]})
	if turn == 0:
		turn = 1
		active_tab = 0
		update_tab_buttons()
		started = Time.get_ticks_msec()
		if game.players[1].is_cpu: auto_prepare(1)
	game.launch_round()
	refresh()
# Deterministic tag-based heuristic; the same state methods enforce every CPU limit.
func affinity(id, gun: int, equipped: Array = []) -> int:
	# P5 mod tokens ("mod:<weapon_id>:<key>") aren't relics; score them like a solid-but-not-
	# best pick when they target the CPU's current main, and never applicable otherwise (a
	# stale token for a main the CPU has since switched away from — see MatchState.mod_reason).
	if typeof(id) == TYPE_STRING:
		var parsed := Weapons.parse_mod_token(id)
		return 3 if not parsed.is_empty() and parsed.weapon_id == gun else 0
	var g := Weapons.definition(maxi(0,gun))
	if id == 2: return 0 if ["split","comet","gravity","boomerang","seed","bubble","clover"].any(func(tag): return g.get(tag,false)) else 4
	if id == 11: return 4 if int(g.get("bounce",0)) > 0 or (2 in equipped and affinity(2,gun) > 0) else 0
	if id == 7: return 3 if int(g.mag) <= 6 else 1
	if id == 1: return 3 if int(g.mag) <= 6 else 2
	if id == 6: return 3 if int(g.get("count",1)) > 1 else 2
	# P3 additions: only give the two relics with an obvious weapon-tag correlation (bounce
	# for 反響の種, boomerang for 帰還バッテリー) a non-default score, same simple heuristic
	# style as above; the other four (13/15/16/17) apply to any build about equally, so they
	# keep the generic fallback score of 2 rather than a fabricated preference.
	if id == 12: return 4 if int(g.get("bounce",0)) > 0 or (2 in equipped and affinity(2,gun) > 0) else 1
	if id == 14: return 4 if g.get("boomerang",false) else 1
	return 2
func auto_prepare(i: int) -> void:
	var state = game.match_state
	var guns: Array = state.weapons[i].duplicate()
	guns.sort_custom(func(a,b): return weapon_score(a,state.builds[i].equipped) > weapon_score(b,state.builds[i].equipped))
	state.set_main(i,guns[0])
	var candidates: Array = state.rewards[i].duplicate()
	if state.temporary[i] >= 0: candidates.append(state.temporary[i])
	candidates.sort_custom(func(a,b): return affinity(a,state.builds[i].main,state.builds[i].equipped) > affinity(b,state.builds[i].main,state.builds[i].equipped))
	for id in candidates:
		if state.remaining[i] <= 0: break
		if id in state.builds[i].owned: continue
		# A mod-token claim never touches owned/equipped, so it never needs the 8-slot
		# discard-to-make-room step below — only guard it for an actual relic id.
		if typeof(id) != TYPE_STRING and state.builds[i].owned.size() >= 8:
			state.discard(i,state.builds[i].owned.back())
		state.claim(i,id)
	var owned: Array = state.builds[i].owned.duplicate()
	owned.sort_custom(func(a,b): return affinity(a,state.builds[i].main,state.builds[i].equipped) > affinity(b,state.builds[i].main,state.builds[i].equipped))
	for id in state.builds[i].equipped.duplicate(): state.toggle(i,id)
	for id in owned.slice(0,state.capacity()): state.toggle(i,id)
	state.confirm(i)
	game.telemetry.record("cpu_prepare",{"player":i,"build":state.builds[i]})
func weapon_score(id: int, relics: Array) -> int:
	var score := 0
	for relic in relics: score += affinity(relic,id,relics)
	return score + ["C","B","A","S"].find(Weapons.definition(id).rarity)
func label_at(parent: Node, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = 320
	label.add_theme_font_size_override("font_size",14)
	parent.add_child(label)
func button_at(parent: Node, text: String, action: Callable, disabled: bool = false, tooltip: String = "") -> Button:
	var button := Button.new()
	button.text = text
	button.disabled = disabled
	button.custom_minimum_size = Vector2(320,30)
	button.clip_text = true
	button.add_theme_font_size_override("font_size",14)
	if tooltip != "": button.tooltip_text = tooltip
	button.pressed.connect(action)
	parent.add_child(button)
	return button
# P5: parses either candidate type into a display {name,desc} pair — a relic id via the relic
# catalog, a "mod:<weapon_id>:<key>" token via the owning weapon's mod branch definition.
func reward_info(id) -> Dictionary:
	if typeof(id) == TYPE_STRING:
		var parsed := Weapons.parse_mod_token(id)
		var mod := Weapons.mod_definition(parsed.weapon_id,parsed.mod_key)
		return {"name":Weapons.definition(parsed.weapon_id).name+"改造："+str(mod.name),"desc":str(mod.desc)}
	return {"name":Relics.definition(id).name,"desc":Relics.definition(id).desc}
func build_text(build: Dictionary) -> String:
	var names: Array = build.equipped.map(func(id): return Relics.definition(id).name)
	var mods: Dictionary = build.get("mods",{})
	var mod_tag := "" if mods.is_empty() else "・改造%d件" % mods.size()
	return (Weapons.definition(build.main).name if build.main >= 0 else "未確定") + mod_tag + " / " + "・".join(names)
func refresh() -> void:
	$Root.visible = game.phase == "prepare"
	if not $Root.visible: return
	var state = game.match_state
	var build: Dictionary = state.builds[turn]
	$Root/Panel/Content/Title.text = "P%d 準備  |  成長 %d  |  装備 %d/%d ・ 所持庫 %d/8" % [turn+1,state.stage,build.equipped.size(),state.capacity(),build.owned.size()]
	$Root/Panel/Content/Info.text = "相手の前ラウンド確定ビルド：" + build_text(state.previous[1-turn])
	$Root/Panel/Content/Info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	$Root/Panel/Content/Ready.text = "準備完了" if turn == 0 and not game.players[1].is_cpu else "準備完了・対戦開始"
	$Root/Panel/Content/Ready.disabled = build.main < 0 or (state.remaining[turn] > 0 and state.rewards[turn].any(func(id): return state.reason(turn,id) == ""))
	$Root/Panel/Content/Notice.text = "報酬残り%d回。主力と報酬（レリック取得／主力改造）を選び、装備を整理して準備完了。G/Hで仮装備（1ラウンド1個）。\n着脱では回復せず戦闘開始時に全快。時間制限なし。ローカル2人では画面上の選択は秘匿できません。" % state.remaining[turn]
	if not build.get("mods",{}).is_empty(): $Root/Panel/Content/Notice.text += "\n武器改造は武器ごとに紐づき、主力を切り替えても消えませんが、その武器を主力にしている間だけ有効です。"
	var scroll_positions: Array = []
	for child in $Root/Panel/Content/Cards.get_children():
		scroll_positions.append(child.scroll_vertical if scroll_turn == turn else 0)
		child.get_parent().remove_child(child)
		child.queue_free()
	scroll_turn = turn
	var columns: Array = []
	for n in range(3):
		var scroll := ScrollContainer.new()
		scroll.custom_minimum_size = Vector2(340,330)
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		$Root/Panel/Content/Cards.add_child(scroll)
		var column := VBoxContainer.new()
		column.custom_minimum_size.x = 320
		scroll.add_child(column)
		columns.append(column)
		scroll.visible = n == active_tab
		if n < scroll_positions.size(): scroll.set_deferred("scroll_vertical",scroll_positions[n])
	label_at(columns[0],"主力1丁を指定（サイドアーム常備）")
	label_at(columns[0],"開始時HP：%d / パルス：%d" % [game.players[turn].max_hp+(2 if 4 in build.equipped else 0),game.players[turn].initial_pulses])
	var mods: Dictionary = build.get("mods",{})
	for id in state.weapons[turn]:
		var mod_tag := "　⚙"+str(Weapons.mod_definition(id,mods[id]).name) if mods.has(id) else ""
		var weapon_desc: String = Weapons.definition(id).desc
		if mods.has(id): weapon_desc += "\n⚙"+str(Weapons.mod_definition(id,mods[id]).name)+"："+str(Weapons.mod_definition(id,mods[id]).desc)
		button_at(columns[0],("✓ " if id == build.main else "")+Weapons.definition(id).name+mod_tag,select_gun.bind(id),false,weapon_desc)
	label_at(columns[1],"無料レリック報酬／主力改造：初回2個 / 以後1個。取得したレリックは控えに入ります（レリック配置タブでグリッドへ）")
	var candidates: Array = state.rewards[turn].duplicate()
	if state.temporary[turn] >= 0 and state.temporary[turn] not in candidates: candidates.append(state.temporary[turn])
	for id in candidates:
		var reason: String = state.reason(turn,id)
		var info := reward_info(id)
		var is_mod := typeof(id) == TYPE_STRING
		var compat: String = "主力の改造" if is_mod else ("主力には適用なし" if affinity(id,build.main,build.equipped) == 0 else ("良好" if affinity(id,build.main,build.equipped) >= 3 else "汎用"))
		var reward_label: String = info.name+"（"+compat+"）"+("（仮装備を確保）" if not is_mod and id == state.temporary[turn] else "")
		var tip: String = info.desc + "\n相性：" + compat + (" / "+reason if reason != "" else "")
		button_at(columns[1],reward_label,claim.bind(id),reason != "",tip)
	# P8x：レリックはグリッドへドラッグして配置する。着脱の可否はグリッドに実際にその形状が
	# 収まる空きマスがあるかどうかだけで決まる（個数上限は撤廃済み）。満杯時は控えへドラッグ
	# で戻してから別のレリックを置く。
	label_at(columns[2],"レリックをグリッドへドラッグして配置。外すときは下の「控えへ戻す」枠へドラッグ。")
	build_relic_grid(columns[2],state,turn,build)
	label_at(columns[2],"控え（ドラッグで解除、×で所持庫から完全放棄）")
	var tray := RelicTray.new()
	tray.on_drop = unequip_relic
	tray.custom_minimum_size = Vector2(300,48)
	columns[2].add_child(tray)
	var tray_list := HFlowContainer.new()
	columns[2].add_child(tray_list)
	for id in build.owned:
		if id in build.equipped: continue
		var row := HBoxContainer.new()
		var chip := RelicChip.new()
		chip.relic_id = id
		chip.text = Relics.definition(id).name
		chip.tooltip_text = Relics.definition(id).name+"："+Relics.definition(id).desc
		chip.custom_minimum_size = Vector2(150,32)
		row.add_child(chip)
		var x_button := Button.new()
		x_button.text = "×"
		x_button.tooltip_text = "破棄："+Relics.definition(id).name+"（所持庫から完全に外す）"
		x_button.custom_minimum_size = Vector2(28,32)
		x_button.pressed.connect(discard.bind(id))
		row.add_child(x_button)
		tray_list.add_child(row)
# 現在の段階のグリッドを描画する。空きマスはドロップ受付のみのPanel、装備品の基準マス
# （position）にはドラッグ可能なRelicChipを乗せる。多マス形状の基準マス以外のセルは
# 単に薄く色付けするだけ（子コントロールを重ねず、ドロップ判定をセル自身に残す）。
func build_relic_grid(parent: Node, state, i: int, build: Dictionary) -> void:
	var size: Vector2i = state.grid_size()
	var occupied: Dictionary = state.occupied_cells(i)
	var positions: Dictionary = build.get("positions",{})
	var grid := GridContainer.new()
	grid.columns = size.x
	parent.add_child(grid)
	for y in range(size.y):
		for x in range(size.x):
			var cell := Vector2i(x,y)
			var panel := RelicGridCell.new()
			panel.game = game
			panel.player_index = i
			panel.cell = cell
			panel.on_drop = place_relic
			panel.custom_minimum_size = Vector2(46,46)
			if occupied.has(cell):
				var id: int = occupied[cell]
				if positions.get(id,cell) == cell:
					var chip := RelicChip.new()
					chip.relic_id = id
					chip.text = Relics.definition(id).name.left(4)
					chip.tooltip_text = Relics.definition(id).name+"："+Relics.definition(id).desc
					chip.custom_minimum_size = Vector2(42,42)
					panel.add_child(chip)
				else:
					panel.self_modulate = Color(1,1,1,.55) # 同じレリックの基準マス以外のセル
			grid.add_child(panel)
