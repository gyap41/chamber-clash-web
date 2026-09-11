extends CanvasLayer
const CpuPreparation = preload("res://scripts/ai/cpu_preparation.gd")
const Items = preload("res://scripts/game/item_identity.gd")
const Weapons = preload("res://scripts/catalog/weapon_catalog.gd")
const Relics = preload("res://scripts/catalog/relic_catalog.gd")
const RelicChip = preload("res://scripts/ui/relic_chip.gd")
const RelicGridCell = preload("res://scripts/ui/relic_grid_cell.gd")
const RelicTray = preload("res://scripts/ui/relic_tray.gd")
const Footprint = preload("res://scripts/ui/item_footprint.gd")
const CELL_SIZE := 58
const CELL_GAP := 4
const CELL_PITCH := CELL_SIZE+CELL_GAP
var game
var turn := 0
var shop_ready: Array:
	get: return game.match_state.ready
var started := 0
var selected_detail = null
var selected_reward := false
var detail_description: Label
var selected_expansion := ""
var placement_entry = null
var preview_cells: Array = []
var reserve_scroll := 0
var scroll_to_latest := false
var rendered_turn := -1
func _ready() -> void:
	$Root/Panel/Content/Ready.pressed.connect(ready_shop)
	style_button($Root/Panel/Content/Ready,true)
func begin() -> void:
	turn = 0
	selected_expansion = ""
	selected_detail = null
	placement_entry = null
	reserve_scroll = 0
	scroll_to_latest = false
	rendered_turn = -1
	started = Time.get_ticks_msec()
	refresh()
func claim(id) -> bool:
	if game.phase != "prepare": return false
	var state = game.match_state
	var card: Dictionary = state.product(turn,str(id))
	var entry = card.entry if not card.is_empty() else id
	var success: bool
	if str(id) == "field":
		entry = state.temporary[turn]
		success = state.claim_temporary(turn)
	else: success = state.purchase(turn,str(id)) if not card.is_empty() else state.claim(turn,id)
	if not success: return false
	selected_expansion = ""
	game.telemetry.record("purchase",{"player":turn,"card":id,"entry":entry,"gold":state.gold[turn]})
	selected_reward = str(entry).begins_with("mod:")
	selected_detail = entry if selected_reward else state.builds[turn].owned.back()
	if not selected_reward: placement_entry = selected_detail
	scroll_to_latest = true
	refresh()
	return true
func refresh_shop() -> void:
	if game.phase != "prepare" or not game.match_state.refresh_shop(turn): return
	selected_detail = null
	refresh()
# P8 配置基盤：ドラッグ＆ドロップでの配置・移動（グリッドのマスへドロップ）。可否は
# match_state.place()＝そのマスに形状が実際に収まるかどうかだけで決まる。同じマスへ置き直す等、
# 実際には何も変わらないドロップでも一律refresh()するが、副作用はなく無害。
# P8y 取得と配置の分離：人間が装備する経路はこのplace()だけになった。位置を自動で決める
# match_state.toggle()の装備側を呼ぶ人間向けラッパー（旧toggle()）は、報酬取得時の即時装備と
# あわせて撤去してある——自動配置を使うのはauto_prepare()＝CPUだけ。
func place_relic(id, cell: Vector2i) -> void:
	if game.phase != "prepare": return
	if not game.match_state.place(turn,id,cell):
		preview_at(id,cell)
		return
	game.telemetry.record("place_relic",{"player":turn,"id":id,"cell":cell})
	placement_entry = null
	refresh()
# 控え（RelicTray）へドラッグで戻したときの解除。すでに未装備のレリックを誤ってここへ落として
# もtoggle()を呼ばない（toggle()は「未装備なら装備」に倒れるため、無関係な誤装備を防ぐ）。
func unequip_relic(id) -> void:
	if game.phase != "prepare" or id not in game.match_state.builds[turn].equipped: return
	if not game.match_state.toggle(turn,id):
		set_status("控えが満杯：先に配置か破棄",Color("ffad83"))
		return
	game.telemetry.record("unequip_relic",{"player":turn,"id":id})
	placement_entry = null
	refresh()
func discard(id) -> void:
	if game.phase != "prepare": return
	if game.match_state.sell(turn,id): game.telemetry.record("discard",{"player":turn,"id":id})
	placement_entry = null
	selected_detail = null
	refresh()
func ready_shop() -> void:
	if game.phase != "prepare" or not game.match_state.confirm(turn): return
	game.telemetry.record("preparation",{"player":turn,"seconds":(Time.get_ticks_msec()-started)/1000.0,"build":game.match_state.builds[turn]})
	if turn == 0:
		turn = 1
		selected_expansion = ""
		selected_detail = null
		placement_entry = null
		reserve_scroll = 0
		scroll_to_latest = false
		started = Time.get_ticks_msec()
		if game.players[1].is_cpu: auto_prepare(1)
	game.launch_round()
	refresh()
# Deterministic tag-based heuristic; the same state methods enforce every CPU limit.
# P8z：基準が「主力1丁」から「グリッドに置いている武器（複数丁）」に変わったため、gunsは配列で
# 受け取る。相性そのものの計算は先頭の1丁（＝グリッドの読み順で最初の武器）を代表として使う
# 単純な近似で、丸腰のときは武器0の定義を仮の基準にする（従来のmaxi(0,gun)と同じ扱い）。
func affinity(id, guns: Array, equipped: Array = []) -> int:
	return CpuPreparation.affinity(id,guns,equipped)
func auto_prepare(i: int) -> void:
	CpuPreparation.auto_prepare(game.match_state,i)
	game.telemetry.record("cpu_prepare",{"player":i,"build":game.match_state.builds[i],"gold":game.match_state.gold[i]})
func purchase_score(card: Dictionary, i: int) -> float:
	return CpuPreparation.purchase_score(card,game.match_state,i)
func weapon_score(id: int, relics: Array) -> int:
	return CpuPreparation.weapon_score(id,relics)
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
# P8z：所持庫・グリッドに載る要素（武器＝"gun:<id>"／レリック＝int）の表示名と説明。改造済みの
# 武器は名前の後ろに⚙で分岐名を添える。
func entry_info(entry) -> Dictionary:
	var state = game.match_state
	if state.is_gun(entry):
		var id: int = state.gun_id(entry)
		var g: Dictionary = Weapons.definition(id)
		var mods: Dictionary = state.builds[turn].get("mods",{})
		var mod_tag := "　⚙"+str(Weapons.mod_definition(id,mods[id]).name) if mods.has(id) else ""
		var desc: String = str(g.desc)
		if mods.has(id): desc += "\n⚙"+str(Weapons.mod_definition(id,mods[id]).name)+"："+str(Weapons.mod_definition(id,mods[id]).desc)
		desc += "\n" + Weapons.stats_text(Weapons.resolved_definition(id,str(mods.get(id,""))))
		return {"name":str(g.name)+mod_tag,"desc":desc}
	return {"name":str(Relics.definition(game.match_state.relic_id(entry)).name),"desc":str(Relics.definition(game.match_state.relic_id(entry)).desc)}
# P5: parses either candidate type into a display {name,desc} pair — a relic id via the relic
# catalog, a "mod:<weapon_id>:<key>" token via the owning weapon's mod branch definition.
func reward_info(id) -> Dictionary:
	if game.match_state.is_gun(id): return entry_info(id)
	if typeof(id) == TYPE_STRING:
		var parsed := Weapons.parse_mod_token(id)
		var mod := Weapons.mod_definition(parsed.weapon_id,parsed.mod_key)
		return {"name":Weapons.definition(parsed.weapon_id).name+"改造："+str(mod.name),"desc":str(mod.desc)}
	return {"name":Relics.definition(id).name,"desc":Relics.definition(id).desc}
func build_text(build: Dictionary) -> String:
	# P8z：装備は武器とレリックが混ざった1本の配列になった。武器を先に並べて「何を持って出るか」
	# が頭に来るようにし、1丁も置いていなければ素手と明示する。
	var state = game.match_state
	var gun_names: Array = build.equipped.filter(func(e): return state.is_gun(e)).map(func(e): return str(Weapons.definition(state.gun_id(e)).name))
	var relic_names: Array = build.equipped.filter(func(e): return state.is_relic(e)).map(func(e): return str(Relics.definition(state.relic_id(e)).name))
	var mods: Dictionary = build.get("mods",{})
	var mod_tag := "" if mods.is_empty() else "・改造%d件" % mods.size()
	return ("素手" if gun_names.is_empty() else "・".join(gun_names)) + mod_tag + " / " + "・".join(relic_names)
# Full-screen preparation: rewards / equipment / reserve and persistent details.
func panel_at(parent: Node, node_name: String, rect: Rect2) -> Panel:
	var panel := Panel.new()
	panel.name = node_name
	panel.position = rect.position
	panel.size = rect.size
	var style := StyleBoxFlat.new()
	style.bg_color = Color("182534")
	style.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel",style)
	parent.add_child(panel)
	return panel
func text_at(parent: Node, node_name: String, text: String, rect: Rect2, font_size: int = 18, color: Color = Color("e4edf5")) -> Label:
	var label := Label.new()
	label.name = node_name
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.clip_text = true
	label.max_lines_visible = 2 if rect.size.y >= 40 else 1
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",color)
	# Configure wrapping before text/size: an unwrapped label can otherwise retain
	# its full-text minimum width even after switching to wrapping or ellipsis.
	label.text = text
	label.position = rect.position
	label.size = rect.size
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label
func style_button(button: Button, accent: bool = false) -> void:
	for state_name in ["normal","hover","pressed","disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("69d9c2") if accent else Color("223648")
		if state_name == "hover": style.bg_color = style.bg_color.lightened(.12)
		if state_name == "pressed": style.bg_color = style.bg_color.darkened(.12)
		if state_name == "disabled": style.bg_color = Color("25303d")
		style.set_corner_radius_all(6)
		style.content_margin_left = 10
		style.content_margin_right = 10
		button.add_theme_stylebox_override(state_name,style)
	button.add_theme_color_override("font_color",Color("101925") if accent else Color("e4edf5"))
	button.add_theme_color_override("font_hover_color",Color("101925") if accent else Color("ffffff"))
	button.add_theme_color_override("font_pressed_color",Color("101925") if accent else Color("ffffff"))
	button.add_theme_color_override("font_disabled_color",Color("8c9cab"))
	button.add_theme_font_size_override("font_size",18)
	var focus_style := StyleBoxFlat.new()
	focus_style.bg_color = Color.TRANSPARENT
	focus_style.border_color = Color("cdefff")
	focus_style.set_border_width_all(2)
	button.add_theme_stylebox_override("focus",focus_style)
func scroll_at(parent: Node, node_name: String, rect: Rect2) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = node_name
	scroll.position = rect.position
	scroll.size = rect.size
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	parent.add_child(scroll)
	var list := VBoxContainer.new()
	list.name = "List"
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation",10)
	scroll.add_child(list)
	return list
func same_entry(a, b) -> bool:
	return Items.same_entry(a,b)
func detail_path() -> Node:
	return $Root/Panel/Content/Cards/Equipment/Details
func show_detail(entry, reward: bool = false) -> void:
	if not selected_expansion.is_empty(): return
	if placement_entry != null and (reward or not same_entry(entry,placement_entry)): return
	var info := reward_info(entry) if reward else entry_info(entry)
	selected_detail = entry
	selected_reward = reward
	var details := detail_path()
	details.get_node("Name").text = info.name
	details.get_node("Name").tooltip_text = info.name
	detail_description.text = info.desc
	var relic: int = game.match_state.relic_id(entry)
	if Relics.stackable(relic):
		var equipped: Array = game.match_state.equipped_relics(turn)
		var count: int = equipped.count(relic)
		var stat := "move_bonus" if relic == 18 else "shot_bonus"
		detail_description.text += "\n\n装備中%d個 / 同種合計+%d%%" % [count,roundi(count*float(Relics.definition(relic).get(stat,0.0))*100)]
	var is_mod: bool = reward and str(entry).begins_with("mod:")
	details.get_node("Meta").text = "武器に紐づく改造" if is_mod else "%dマス / %s" % [game.match_state.shape_of(entry).size(),"武器" if game.match_state.is_gun(entry) else "レリック"]
	var discard_button: Button = details.get_node("Discard")
	discard_button.visible = not reward and entry in game.match_state.builds[turn].owned
	discard_button.text = "売却 %dG" % game.match_state.sale_value(turn,entry) if game.match_state.sale_value(turn,entry) > 0 else "破棄（無料品）"
func select_entry(entry) -> void:
	selected_expansion = ""
	placement_entry = entry
	show_detail(entry)
	set_status("配置先をクリック\nEscで選択解除",Color("83deca"))
func cancel_placement() -> void:
	selected_expansion = ""
	placement_entry = null
	clear_preview()
	set_status("品を選択 → マスをクリック\nドラッグでも配置できます",Color("91a7bc"))
func click_cell(cell: Vector2i) -> void:
	if not selected_expansion.is_empty():
		if game.phase != "prepare": return
		if game.match_state.place_expansion(turn,selected_expansion,cell):
			game.telemetry.record("bag_expansion",{"player":turn,"shape":selected_expansion,"anchor":cell})
			selected_expansion = ""
			selected_detail = null
			refresh()
		else: preview_expansion(cell)
		return
	if placement_entry != null:
		place_relic(placement_entry,cell)
	else:
		var occupied: Dictionary = game.match_state.occupied_cells(turn)
		if occupied.has(cell): select_entry(occupied[cell])
func discard_selected() -> void:
	if selected_detail != null and not selected_reward: discard(selected_detail)
func return_selected() -> void:
	if placement_entry != null: unequip_relic(placement_entry)
func set_status(text: String, color: Color) -> void:
	if not has_node("Root/Panel/Content/Cards/Equipment/Details/Status"): return
	var status := detail_path().get_node("Status") as Label
	status.text = text
	status.add_theme_color_override("font_color",color)
func clear_preview() -> void:
	for panel in preview_cells:
		if is_instance_valid(panel):
			panel.preview_color = Color.TRANSPARENT
			panel.queue_redraw()
	preview_cells.clear()
func preview_at(entry, anchor: Vector2i) -> bool:
	clear_preview()
	var state = game.match_state
	var valid: bool = state.fits(turn,entry,anchor,entry)
	var outside := false
	var locked := false
	var size: Vector2i = state.MAX_GRID_SIZE
	var grid := $Root/Panel/Content/Cards/Equipment/Grid
	for offset in state.shape_of(entry):
		var cell: Vector2i = anchor+offset
		if cell.x < 0 or cell.y < 0 or cell.x >= size.x or cell.y >= size.y:
			outside = true
			continue
		if not state.usable_cells(turn).has(cell): locked = true
		var panel = grid.get_child(cell.y*size.x+cell.x)
		panel.preview_color = Color("8ff4bf") if valid else Color("ffad83")
		panel.queue_redraw()
		preview_cells.append(panel)
	set_status("ここに置けます" if valid else ("配置不可：グリッドの外" if outside else ("配置不可：未開放マス" if locked else "配置不可：他の装備と重複")),Color("8ff4bf") if valid else Color("ffad83"))
	if state.is_gun(entry) and entry not in state.builds[turn].equipped and state.carried_guns(turn).size() >= state.MAX_CARRIED_WEAPONS:
		set_status("配置不可：携行武器は8丁まで",Color("ffad83"))
	return valid
func _input(event: InputEvent) -> void:
	if game == null or game.phase != "prepare": return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE and (placement_entry != null or not selected_expansion.is_empty()):
		cancel_placement()
		get_viewport().set_input_as_handled()
func select_expansion(shape: String) -> void:
	var reason: String = game.match_state.expansion_offer_reason(turn,shape)
	if not reason.is_empty():
		cancel_placement()
		set_status(reason,Color("ffad83"))
		return
	placement_entry = null
	selected_detail = null
	selected_expansion = shape
	detail_path().get_node("Name").text = game.match_state.Expansions.NAMES[shape]
	detail_path().get_node("Meta").text = "%dマス / %dG" % [game.match_state.Expansions.SHAPES[shape].size(),game.match_state.Expansions.SHAPES[shape].size()]
	detail_description.text = "未開放マスに置き、バッグの辺に接続します。回転なし。配置後は固定。配置成功時のみ支払い。各準備1個まで。上限24マス。控えは消費しません。"
	detail_path().get_node("Discard").visible = false
	set_status("バッグの配置先をクリック\n配置確定で支払い / Esc取消",Color("83deca"))
func preview_expansion(anchor: Vector2i) -> bool:
	clear_preview()
	var state = game.match_state
	var reason: String = state.expansion_reason(turn,selected_expansion,anchor)
	var grid := $Root/Panel/Content/Cards/Equipment/Grid
	for offset in state.Expansions.SHAPES[selected_expansion]:
		var cell: Vector2i = anchor+offset
		if cell.x < 0 or cell.y < 0 or cell.x >= 6 or cell.y >= 6: continue
		var panel = grid.get_child(cell.y*6+cell.x)
		panel.preview_color = Color("8ff4bf") if reason.is_empty() else Color("ffad83")
		panel.queue_redraw()
		preview_cells.append(panel)
	set_status("クリックで拡張を確定" if reason.is_empty() else "配置不可："+reason,Color("8ff4bf") if reason.is_empty() else Color("ffad83"))
	return reason.is_empty()
func _process(_delta: float) -> void:
	if game == null or game.phase != "prepare" or not has_node("Root/Panel/Content/Cards/Equipment/Grid"): return
	var entry = placement_entry
	var offset := Vector2i.ZERO
	if get_viewport().gui_is_dragging():
		var data = get_viewport().gui_get_drag_data()
		if typeof(data) == TYPE_DICTIONARY and data.has("entry"):
			entry = data.entry
			offset = data.get("grab_offset",Vector2i.ZERO)
	if entry == null and selected_expansion.is_empty():
		clear_preview()
		return
	var grid := $Root/Panel/Content/Cards/Equipment/Grid
	var local: Vector2 = grid.get_local_mouse_position()
	var size: Vector2i = game.match_state.MAX_GRID_SIZE
	if local.x >= 0 and local.y >= 0 and local.x < size.x*CELL_PITCH-CELL_GAP and local.y < size.y*CELL_PITCH-CELL_GAP:
		var anchor := Vector2i(floori(local.x/CELL_PITCH),floori(local.y/CELL_PITCH))-offset
		if not selected_expansion.is_empty(): preview_expansion(anchor)
		else: preview_at(entry,anchor)
	else:
		clear_preview()
		set_status("バッグの配置先をクリック\n配置確定で支払い / Esc取消" if not selected_expansion.is_empty() else "配置先をクリック / ドラッグ\nEscで選択解除",Color("83deca"))
func add_footprint(parent: Node, entry, rect: Rect2) -> void:
	var icon := Footprint.new()
	icon.shape = game.match_state.shape_of(entry)
	icon.tint = Color("79cbe8") if game.match_state.is_gun(entry) else Color(Relics.definition(game.match_state.relic_id(entry)).color).lightened(.2)
	icon.position = rect.position
	icon.size = rect.size
	parent.add_child(icon)
func refresh() -> void:
	$Root.visible = game.phase == "prepare"
	if not $Root.visible: return
	clear_preview()
	var state = game.match_state
	var build: Dictionary = state.builds[turn]
	state.sync_mod_product(turn)
	$Root/Panel/Content/Title.text = "P%d  ラウンド準備" % (turn+1)
	$Root/Panel/Content/Info.text = "準備 %d / 5本先取 / SCORE %d : %d / %dG" % [state.stage,state.scores[0],state.scores[1],state.gold[turn]]
	$Root/Panel/Content/Info.tooltip_text = "相手の前ラウンド確定ビルド：" + build_text(state.previous[1-turn]) + "\nローカル2人では選択を秘匿できません。"
	$Root/Panel/Content/Ready.text = "準備完了・対戦開始" if turn == 1 or game.players[1].is_cpu else "準備完了・P2へ"
	$Root/Panel/Content/Ready.disabled = state.ready[turn]
	var guns: Array = state.carried_guns(turn)
	var names: Array = guns.map(func(id): return str(Weapons.definition(id).name))
	$Root/Panel/Content/Notice.text = "HP %d   /   パルス %d   /   携行 %d丁   /   残金 %dG" % [game.players[turn].max_hp+(2 if 4 in state.equipped_relics(turn) else 0),game.players[turn].initial_pulses,guns.size(),state.gold[turn]]
	$Root/Panel/Content/Summary.text = "未確保の無料品あり：出撃すると失います" if state.temporary[turn] >= 0 else ("武器未配置：近接のみで出撃" if guns.is_empty() else "携行：" + " / ".join(names))
	$Root/Panel/Content/Summary.tooltip_text = ("未確保のフィールドレリックは出撃で失います。\n" if state.temporary[turn] >= 0 else "") + " / ".join(names) + "\n武器の順番はグリッドの左上から。戦闘開始時に全快。"
	var old_scroll := get_node_or_null("Root/Panel/Content/Cards/Reserve/Scroll") as ScrollContainer
	if old_scroll and rendered_turn == turn: reserve_scroll = old_scroll.scroll_horizontal
	rendered_turn = turn
	for child in $Root/Panel/Content/Cards.get_children():
		child.get_parent().remove_child(child)
		child.queue_free()
	var cards := $Root/Panel/Content/Cards
	var equipment := panel_at(cards,"Equipment",Rect2(0,0,704,440))
	var rewards := panel_at(cards,"Rewards",Rect2(720,0,352,544))
	var reserve := panel_at(cards,"Reserve",Rect2(0,456,704,88))
	var details := panel_at(equipment,"Details",Rect2(424,56,264,376))
	text_at(equipment,"Heading","バックパック",Rect2(24,16,240,32),24)
	text_at(equipment,"Capacity","%d / %d マス" % [state.occupied_cells(turn).size(),state.capacity(turn)],Rect2(274,22,160,26),18,Color("83deca"))
	build_relic_grid(equipment,state,turn,build)
	text_at(details,"Heading","アイテム詳細",Rect2(12,4,240,26),16,Color("91a7bc"))
	var title := text_at(details,"Name","品を選んで詳細を確認",Rect2(12,40,240,64),20,Color("83deca"))
	title.max_lines_visible = 2
	title.mouse_filter = Control.MOUSE_FILTER_PASS
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	text_at(details,"Meta","形のサムネイル = 占有マス",Rect2(12,110,240,24),15,Color("91a7bc"))
	var detail_list := scroll_at(details,"TextScroll",Rect2(12,142,240,118))
	detail_description = Label.new()
	detail_description.name = "Description"
	detail_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_description.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_description.add_theme_font_size_override("font_size",17)
	detail_description.text = "武器とレリックを配置して、次のラウンドへ。"
	detail_list.add_child(detail_description)
	text_at(details,"Status","品を選択 → マスをクリック\nドラッグでも配置できます",Rect2(12,272,240,48),16,Color("91a7bc"))
	var cancel := Button.new()
	cancel.name = "Cancel"
	cancel.position = Vector2(12,330)
	cancel.size = Vector2(110,40)
	cancel.text = "選択解除"
	style_button(cancel)
	cancel.add_theme_font_size_override("font_size",15)
	cancel.pressed.connect(cancel_placement)
	details.add_child(cancel)
	var discard_button := Button.new()
	discard_button.name = "Discard"
	discard_button.position = Vector2(136,330)
	discard_button.size = Vector2(116,40)
	discard_button.text = "売却 / 破棄"
	discard_button.tooltip_text = "完全に手放す操作です。控えへの移動とは異なります。"
	style_button(discard_button)
	discard_button.add_theme_font_size_override("font_size",14)
	discard_button.add_theme_color_override("font_color",Color("ffad83"))
	discard_button.visible = false
	discard_button.pressed.connect(discard_selected)
	details.add_child(discard_button)
	text_at(rewards,"Heading","ショップ",Rect2(20,16,312,32),24)
	text_at(rewards,"Remaining","%dG / 購入は任意・控えへ追加" % state.gold[turn],Rect2(20,60,312,32),17,Color("83deca"))
	var reward_list := scroll_at(rewards,"Scroll",Rect2(20,104,312,424))
	var reroll := button_at(reward_list,"商品更新 2G（各準備1回）",refresh_shop,state.refreshed[turn] or state.gold[turn] < 2 or state.ready[turn])
	reroll.name = "Refresh"
	reroll.custom_minimum_size.x = 0
	# Keep unavailable patches visible with a reason instead of silently hiding them.
	if not state.ended:
		var heading := Label.new()
		heading.text = "拡張 %d/24マス：選択 → 配置" % state.capacity(turn)
		heading.add_theme_font_size_override("font_size",16)
		reward_list.add_child(heading)
		for shape in state.Expansions.SHAPES:
			var choice := Button.new()
			choice.name = "Expansion_"+shape
			var why: String = state.expansion_offer_reason(turn,shape)
			choice.text = state.Expansions.NAMES[shape]+" %dG" % state.Expansions.SHAPES[shape].size()+(" / 選択" if why.is_empty() else "\n"+why)
			choice.disabled = not why.is_empty()
			choice.tooltip_text = "選択後、グリッドの配置先をクリック。確定時のみ支払い。" if why.is_empty() else why
			choice.custom_minimum_size = Vector2(0,44)
			style_button(choice)
			choice.add_theme_font_size_override("font_size",14)
			choice.pressed.connect(select_expansion.bind(shape))
			var footprint := Footprint.new()
			footprint.shape = state.Expansions.SHAPES[shape]
			footprint.position = Vector2(8,8)
			footprint.size = Vector2(26,28)
			footprint.tint = Color("83deca")
			choice.add_child(footprint)
			reward_list.add_child(choice)
	var candidates: Array = state.rewards[turn].duplicate()
	var offers: Array = state.products[turn].duplicate(true)
	if state.temporary[turn] >= 0:
		candidates.append(state.temporary[turn])
		offers.push_front({"id":"field","entry":state.temporary[turn],"price":0,"sold":false})
	for offer in offers:
		var entry = offer.entry
		var reason: String = state.temporary_reason(turn) if offer.id == "field" else state.purchase_reason(turn,offer.id)
		var info := reward_info(entry)
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(0,136)
		reward_list.add_child(card)
		var style := StyleBoxFlat.new()
		style.bg_color = Color("223648")
		style.set_corner_radius_all(6)
		card.add_theme_stylebox_override("panel",style)
		var layout := Control.new()
		layout.custom_minimum_size = Vector2(0,136)
		card.add_child(layout)
		if not str(entry).begins_with("mod:"): add_footprint(layout,entry,Rect2(12,16,32,32))
		else: text_at(layout,"Mod","改",Rect2(12,16,32,32),22)
		var reward_name := text_at(layout,"Name",info.name,Rect2(56,10,232,50),18)
		reward_name.max_lines_visible = 2
		reward_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		var effect := text_at(layout,"Effect",info.desc,Rect2(12,62,276,28),15,Color("b2c6d8"))
		effect.autowrap_mode = TextServer.AUTOWRAP_OFF
		effect.clip_text = true
		effect.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		var why := text_at(layout,"Reason",reason if not reason.is_empty() else ("武器改造" if str(entry).begins_with("mod:") else "%dマス" % state.shape_of(entry).size()),Rect2(12,96,178,34),14,Color("91a7bc"))
		why.max_lines_visible = 2
		var button := Button.new()
		button.name = "Claim"
		button.position = Vector2(198,94)
		button.size = Vector2(90,36)
		button.text = "無料確保" if offer.id == "field" else ("売切" if offer.sold else "%dG 購入" % offer.price)
		button.add_theme_font_size_override("font_size",14)
		button.disabled = not reason.is_empty()
		style_button(button,true)
		button.add_theme_font_size_override("font_size",14)
		button.pressed.connect(claim.bind(offer.id))
		layout.add_child(button)
		layout.tooltip_text = info.name+"\n"+info.desc+"\n"+reason
		layout.mouse_entered.connect(show_detail.bind(entry,true))
		button.focus_entered.connect(show_detail.bind(entry,true))
	text_at(reserve,"Heading","控え",Rect2(16,6,100,24),18)
	var reserve_count: int = build.owned.size()-build.equipped.size()
	text_at(reserve,"Capacity","控え%d / 8個 · 総所持%d   ← 横にスクロール →" % [reserve_count,build.owned.size()],Rect2(96,8,590,24),14,Color("91a7bc"))
	var scroll := ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.position = Vector2(16,34)
	scroll.size = Vector2(520,50)
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	reserve.add_child(scroll)
	var tray_list := HBoxContainer.new()
	tray_list.name = "List"
	tray_list.add_theme_constant_override("separation",8)
	scroll.add_child(tray_list)
	for entry in build.owned:
		if entry in build.equipped: continue
		var chip := RelicChip.new()
		chip.entry = entry
		chip.text = ""
		chip.on_drag_start = select_entry
		chip.custom_minimum_size = Vector2(150,42)
		chip.clip_text = true
		chip.tooltip_text = entry_info(entry).name+"\n"+entry_info(entry).desc
		style_button(chip)
		chip.add_theme_font_size_override("font_size",16)
		chip.pressed.connect(select_entry.bind(entry))
		chip.mouse_entered.connect(show_detail.bind(entry))
		chip.focus_entered.connect(show_detail.bind(entry))
		add_footprint(chip,entry,Rect2(8,9,24,24))
		var caption := text_at(chip,"Caption",entry_info(entry).name,Rect2(40,9,102,24),16)
		caption.autowrap_mode = TextServer.AUTOWRAP_OFF
		caption.clip_text = true
		caption.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		tray_list.add_child(chip)
	if tray_list.get_child_count() == 0:
		var empty := Label.new()
		empty.text = "控えはありません"
		tray_list.add_child(empty)
	scroll.set_deferred("scroll_horizontal",10000 if scroll_to_latest else reserve_scroll)
	scroll_to_latest = false
	var tray := RelicTray.new()
	tray.name = "DropZone"
	tray.position = Vector2(552,34)
	tray.size = Vector2(136,48)
	tray.on_drop = unequip_relic
	var tray_style := StyleBoxFlat.new()
	tray_style.bg_color = Color("23443f")
	tray_style.border_color = Color("83deca")
	tray_style.set_border_width_all(1)
	tray.add_theme_stylebox_override("panel",tray_style)
	reserve.add_child(tray)
	text_at(tray,"Hint","ここへ戻す\n装備解除",Rect2(10,6,116,42),16,Color("83deca"))
	tray.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed: return_selected())
	var selection_exists: bool = selected_detail != null and (selected_detail in candidates if selected_reward else selected_detail in build.owned)
	if placement_entry != null and placement_entry not in build.owned: placement_entry = null
	if selection_exists: show_detail(selected_detail,selected_reward)
	if not selected_expansion.is_empty(): select_expansion(selected_expansion)
func build_relic_grid(parent: Node, state, i: int, build: Dictionary) -> void:
	var size: Vector2i = state.MAX_GRID_SIZE
	var occupied: Dictionary = state.occupied_cells(i)
	var positions: Dictionary = build.get("positions",{})
	var grid := GridContainer.new()
	grid.name = "Grid"
	grid.columns = size.x
	grid.position = Vector2(24,60)
	grid.add_theme_constant_override("h_separation",CELL_GAP)
	grid.add_theme_constant_override("v_separation",CELL_GAP)
	parent.add_child(grid)
	for y in range(size.y):
		for x in range(size.x):
			var cell := Vector2i(x,y)
			var panel := RelicGridCell.new()
			panel.game = game
			panel.player_index = i
			panel.cell = cell
			panel.on_drop = place_relic
			panel.on_click = click_cell
			panel.custom_minimum_size = Vector2(CELL_SIZE,CELL_SIZE)
			var style := StyleBoxFlat.new()
			style.bg_color = Color("243747")
			style.border_color = Color("456174")
			style.set_border_width_all(1)
			if not state.usable_cells(i).has(cell):
				style.bg_color = Color("151f29")
				style.border_color = Color("2c3945")
				panel.tooltip_text = "未開放：バッグ拡張で使用可能になる領域"
				text_at(panel,"Locked","×",Rect2(18,14,24,24),18,Color("65727d"))
			if occupied.has(cell):
				var entry = occupied[cell]
				style.bg_color = Color("30758a") if state.is_gun(entry) else Color(Relics.definition(game.match_state.relic_id(entry)).color).darkened(.5)
				style.border_color = style.bg_color.lightened(.3)
				if occupied.has(cell+Vector2i.LEFT) and same_entry(occupied[cell+Vector2i.LEFT],entry): style.border_width_left = 0
				if occupied.has(cell+Vector2i.RIGHT) and same_entry(occupied[cell+Vector2i.RIGHT],entry): style.border_width_right = 0
				if occupied.has(cell+Vector2i.UP) and same_entry(occupied[cell+Vector2i.UP],entry): style.border_width_top = 0
				if occupied.has(cell+Vector2i.DOWN) and same_entry(occupied[cell+Vector2i.DOWN],entry): style.border_width_bottom = 0
				var chip := RelicChip.new()
				chip.entry = entry
				chip.grab_offset = cell-positions.get(entry,cell)
				chip.on_drag_start = select_entry
				chip.clip_text = true
				chip.tooltip_text = entry_info(entry).name+"\n"+entry_info(entry).desc
				chip.custom_minimum_size = Vector2(CELL_SIZE-4,CELL_SIZE-4)
				chip.position = Vector2(2,2)
				chip.add_theme_font_size_override("font_size",12)
				for name in ["normal","hover","pressed"]: chip.add_theme_stylebox_override(name,StyleBoxEmpty.new())
				chip.pressed.connect(click_cell.bind(cell))
				chip.mouse_entered.connect(show_detail.bind(entry))
				chip.focus_entered.connect(show_detail.bind(entry))
				panel.add_child(chip)
				if positions.get(entry,cell) == cell:
					chip.text = "\n\n"+entry_info(entry).name.left(4)
					if state.is_gun(entry):
						var art := TextureRect.new()
						art.texture = Weapons.art(state.gun_id(entry))
						art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
						art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
						art.position = Vector2(7,3)
						art.size = Vector2(40,25)
						art.mouse_filter = Control.MOUSE_FILTER_IGNORE
						chip.add_child(art)
					else: add_footprint(chip,entry,Rect2(17,4,22,22))
				# Connect cells from the same item across gutters without blocking input.
				for direction in [Vector2i.RIGHT,Vector2i.DOWN]:
					if occupied.has(cell+direction) and same_entry(occupied[cell+direction],entry):
						var bridge := ColorRect.new()
						bridge.color = style.bg_color
						bridge.position = Vector2(CELL_SIZE,0) if direction == Vector2i.RIGHT else Vector2(0,CELL_SIZE)
						bridge.size = Vector2(CELL_GAP,CELL_SIZE) if direction == Vector2i.RIGHT else Vector2(CELL_SIZE,CELL_GAP)
						bridge.mouse_filter = Control.MOUSE_FILTER_IGNORE
						panel.add_child(bridge)
			panel.add_theme_stylebox_override("panel",style)
			grid.add_child(panel)
