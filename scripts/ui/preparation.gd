extends CanvasLayer
const Weapons = preload("res://scripts/catalog/weapon_catalog.gd")
const Relics = preload("res://scripts/catalog/relic_catalog.gd")
var game
var turn := 0
var choices: Array = []
var shop_ready: Array:
	get: return game.match_state.ready
var started := 0
var scroll_turn := -1
func _ready() -> void:
	$Root/Panel/Content/Ready.pressed.connect(ready_shop)
func begin() -> void:
	scroll_turn = -1
	turn = 0
	started = Time.get_ticks_msec()
	choices = game.match_state.weapons[0].duplicate()
	refresh()
func select_gun(id: int) -> bool:
	if game.phase != "prepare" or not game.match_state.set_main(turn,id): return false
	game.telemetry.record("main",{"player":turn,"id":id})
	refresh()
	return true
func claim(id: int) -> bool:
	if game.phase != "prepare" or not game.match_state.claim(turn,id): return false
	game.telemetry.record("reward",{"player":turn,"id":id})
	refresh()
	return true
func toggle(id: int) -> void:
	if game.phase != "prepare": return
	if game.match_state.toggle(turn,id): game.telemetry.record("equip_relic",{"player":turn,"id":id})
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
		started = Time.get_ticks_msec()
		if game.players[1].is_cpu: auto_prepare(1)
	game.launch_round()
	refresh()
# Deterministic tag-based heuristic; the same state methods enforce every CPU limit.
func affinity(id: int, gun: int, equipped: Array = []) -> int:
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
		if state.builds[i].owned.size() >= 8:
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
func button_at(parent: Node, text: String, action: Callable, disabled: bool = false) -> void:
	var button := Button.new()
	button.text = text
	button.disabled = disabled
	button.custom_minimum_size = Vector2(320,30)
	button.clip_text = true
	button.add_theme_font_size_override("font_size",14)
	button.pressed.connect(action)
	parent.add_child(button)
func build_text(build: Dictionary) -> String:
	var names: Array = build.equipped.map(func(id): return Relics.definition(id).name)
	return (Weapons.definition(build.main).name if build.main >= 0 else "未確定") + " / " + "・".join(names)
func refresh() -> void:
	$Root.visible = game.phase == "prepare"
	if not $Root.visible: return
	var state = game.match_state
	var build: Dictionary = state.builds[turn]
	$Root/Panel/Content/Title.text = "P%d 準備  |  成長 %d  |  装備 %d/%d ・ 所持庫 %d/8" % [turn+1,state.stage,build.equipped.size(),state.capacity(),build.owned.size()]
	$Root/Panel/Content/Info.text = "相手の前ラウンド確定ビルド：" + build_text(state.previous[1-turn])
	$Root/Panel/Content/Info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	$Root/Panel/Content/Ready.text = "準備完了" if turn == 0 and not game.players[1].is_cpu else "準備完了・対戦開始"
	$Root/Panel/Content/Ready.disabled = build.main < 0 or (state.remaining[turn] > 0 and state.rewards[turn].any(func(id): return id not in build.owned))
	$Root/Panel/Content/Notice.text = "報酬残り%d回。主力と報酬を選び、装備を整理して準備完了。G/Hで仮装備（1ラウンド1個）。\n着脱では回復せず戦闘開始時に全快。時間制限なし。ローカル2人では画面上の選択は秘匿できません。" % state.remaining[turn]
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
		if n < scroll_positions.size(): scroll.set_deferred("scroll_vertical",scroll_positions[n])
	label_at(columns[0],"主力1丁を指定（サイドアーム常備）")
	label_at(columns[0],"開始時HP：%d / パルス：%d" % [game.players[turn].max_hp+(2 if 4 in build.equipped else 0),game.players[turn].initial_pulses])
	for id in state.weapons[turn]:
		button_at(columns[0],("✓ " if id == build.main else "")+Weapons.definition(id).name,select_gun.bind(id))
		label_at(columns[0],Weapons.definition(id).desc)
	label_at(columns[1],"無料レリック報酬：初回2個 / 以後1個")
	var candidates: Array = state.rewards[turn].duplicate()
	if state.temporary[turn] >= 0 and state.temporary[turn] not in candidates: candidates.append(state.temporary[turn])
	for id in candidates:
		var reason: String = state.reason(turn,id)
		button_at(columns[1],Relics.definition(id).name+("（仮装備を確保）" if id == state.temporary[turn] else ""),claim.bind(id),reason != "")
		label_at(columns[1],Relics.definition(id).desc + "\n相性：" + ("主力には適用なし" if affinity(id,build.main,build.equipped) == 0 else ("良好" if affinity(id,build.main,build.equipped) >= 3 else "汎用")) + (" / "+reason if reason != "" else ""))
	label_at(columns[2],"所持庫：クリックで着脱・満杯時は先に外す")
	for id in build.owned:
		button_at(columns[2],("装備中 " if id in build.equipped else "控え ")+Relics.definition(id).name,toggle.bind(id),id not in build.equipped and build.equipped.size() >= state.capacity())
		label_at(columns[2],Relics.definition(id).desc)
		button_at(columns[2],"破棄："+Relics.definition(id).name,discard.bind(id))
