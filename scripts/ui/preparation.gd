extends CanvasLayer
const CpuPreparation = preload("res://scripts/ai/cpu_preparation.gd")
const Items = preload("res://scripts/game/item_identity.gd")
const Weapons = preload("res://scripts/catalog/weapon_catalog.gd")
const Relics = preload("res://scripts/catalog/relic_catalog.gd")
const RelicChip = preload("res://scripts/ui/relic_chip.gd")
const RelicGridCell = preload("res://scripts/ui/relic_grid_cell.gd")
const RelicTray = preload("res://scripts/ui/relic_tray.gd")
const Footprint = preload("res://scripts/ui/item_footprint.gd")
const CELL_SIZE := 50
const CELL_GAP := 4
const CELL_PITCH := CELL_SIZE+CELL_GAP
var game
var turn := 0
var shop_ready: Array:
	get: return game.match_state.ready
var started := 0
var selected_detail = null
var selected_reward := false
var selected_offer := ""
var latest_purchase = null
var detail_description: Label
var selected_expansion := ""
var placement_entry = null
var preview_cells: Array = []
var rendered_turn := -1
func _ready() -> void:
	$Root/Panel/Content/Ready.pressed.connect(ready_shop)
	style_button($Root/Panel/Content/Ready,true)
func begin() -> void:
	turn = 0
	selected_expansion = ""
	selected_detail = null
	placement_entry = null
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
	placement_entry = null
	selected_offer = ""
	latest_purchase = selected_detail
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
	for i in range(game.players.size()):
		if game.players[i].is_cpu and not game.match_state.ready[i]: auto_prepare(i)
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
		var total := Relics.stack_summary(relic,count)
		if count == 0: total = "効果なし"
		detail_description.text += "\n\n装備中%d個 / 同種合計%s" % [count,total]
	var is_mod: bool = reward and str(entry).begins_with("mod:")
	details.get_node("Meta").text = "武器に紐づく改造" if is_mod else "%dマス / %s" % [game.match_state.shape_of(entry).size(),"武器" if game.match_state.is_gun(entry) else "レリック"]
	var discard_button: Button = details.get_node("Discard")
	discard_button.visible = not reward and entry in game.match_state.builds[turn].owned
	discard_button.text = "売却 %dG" % game.match_state.sale_value(turn,entry) if game.match_state.sale_value(turn,entry) > 0 else "破棄（無料品）"
	var owned: bool = not reward and entry in game.match_state.builds[turn].owned
	details.get_node("Place").visible = owned
	details.get_node("Return").visible = owned and entry in game.match_state.builds[turn].equipped
	details.get_node("Buy").visible = reward and not selected_offer.is_empty()
	if reward and not selected_offer.is_empty():
		var state = game.match_state
		var offer: Dictionary = state.product(turn,selected_offer)
		var free: bool = selected_offer == "field"
		var why: String = state.temporary_reason(turn) if free else state.purchase_reason(turn,selected_offer)
		details.get_node("Buy").text = "無料確保して控えへ" if free else "購入して控えへ %dG" % int(offer.get("price",0))
		details.get_node("Buy").disabled = not why.is_empty()
		details.get_node("Buy").tooltip_text = why
	set_status("ショップの商品を確認中\n購入だけでは装備されません" if reward else "所持品を確認中 / ドラッグで配置",Color("91a7bc"))
	# Compare actual stacked reload multipliers without changing the build.
	if relic == 1 and (reward or entry not in game.match_state.builds[turn].equipped):
		var ids: Array = game.match_state.equipped_relics(turn)
		var before: float = (game.players[turn].reload_duration / 1.15) * Relics.stacked_value(ids,1,"reload_ratio")
		detail_description.text += "\n装填倍率 %.2f → %.2f" % [before,before*float(Relics.definition(1).reload_ratio)]
func select_entry(entry) -> void:
	selected_offer = ""
	selected_expansion = ""
	placement_entry = entry
	show_detail(entry)
	detail_path().get_node("Cancel").disabled = false
	set_status("配置中："+entry_info(entry).name+"\n配置先をクリック / Esc取消",Color("83deca"))
func cancel_placement() -> void:
	selected_expansion = ""
	placement_entry = null
	var popup := get_node_or_null("Root/Panel/Content/Cards/Equipment/ExpansionPopup")
	if popup != null: popup.hide()
	var cancel_button := get_node_or_null("Root/Panel/Content/Cards/Equipment/Details/Cancel")
	if cancel_button != null: cancel_button.disabled = true
	clear_preview()
	set_status("クリックで詳細 / ドラッグで配置",Color("91a7bc"))
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
		if occupied.has(cell): browse_entry(occupied[cell])
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
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE and (placement_entry != null or not selected_expansion.is_empty() or $Root/Panel/Content/Cards/Equipment/ExpansionPopup.visible):
		cancel_placement()
		get_viewport().set_input_as_handled()
func select_expansion(shape: String) -> void:
	$Root/Panel/Content/Cards/Equipment/ExpansionPopup.hide()
	detail_path().get_node("Cancel").disabled = false
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
	for action in ["Discard","Place","Return","Buy"]: detail_path().get_node(action).hide()
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
		set_status("バッグの配置先をクリック\n配置確定で支払い / Esc取消" if not selected_expansion.is_empty() else "配置中："+entry_info(entry).name+"\n配置先をクリック / Esc取消",Color("83deca"))
func add_footprint(parent: Node, entry, rect: Rect2) -> void:
	var icon := Footprint.new()
	icon.shape = game.match_state.shape_of(entry)
	icon.tint = Color("79cbe8") if game.match_state.is_gun(entry) else Color(Relics.definition(game.match_state.relic_id(entry)).color).lightened(.2)
	icon.position = rect.position
	icon.size = rect.size
	parent.add_child(icon)
func browse_entry(entry) -> void:
	cancel_placement()
	selected_offer = ""
	show_detail(entry)

func focus_entry(entry) -> void:
	# Tab navigation can inspect items; drag/placement retains its explicit selection.
	if placement_entry == null and selected_expansion.is_empty(): show_detail(entry)

func inspect_offer(offer_id: String) -> void:
	cancel_placement()
	var state = game.match_state
	var offer: Dictionary = state.product(turn,offer_id)
	if offer_id == "field" and state.temporary[turn] >= 0:
		offer = {"entry":state.temporary[turn]}
	if offer.is_empty(): return
	selected_offer = offer_id
	show_detail(offer.entry,true)

func place_selected() -> void:
	if selected_detail != null and not selected_reward: select_entry(selected_detail)

func buy_selected() -> void:
	if not selected_offer.is_empty(): claim(selected_offer)

func return_detail() -> void:
	if selected_detail != null and not selected_reward: unequip_relic(selected_detail)

func action_button(parent: Node, name_value: String, caption: String, rect: Rect2, callback: Callable, accent: bool = false) -> Button:
	var button := Button.new()
	button.name = name_value
	button.text = caption
	button.position = rect.position
	button.size = rect.size
	style_button(button,accent)
	button.add_theme_font_size_override("font_size",14)
	button.clip_text = true
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func open_expansions() -> void:
	var popup: PanelContainer = $Root/Panel/Content/Cards/Equipment/ExpansionPopup
	var was_visible := popup.visible
	cancel_placement()
	popup.visible = not was_visible

func build_expansions(equipment: Node, state) -> void:
	action_button(equipment,"Expand","バッグを拡張",Rect2(20,436,150,38),open_expansions)
	text_at(equipment,"ExpansionState","今回購入済み" if state.expansion_bought[turn] else "今回 未購入 / 上限24",Rect2(178,445,195,24),13,Color("91a7bc"))
	var popup := PanelContainer.new()
	popup.name = "ExpansionPopup"
	popup.position = Vector2(20,190)
	popup.size = Vector2(350,236)
	popup.z_index = 5
	popup.hide()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("293f52")
	style.set_content_margin_all(10)
	style.set_border_width_all(1)
	style.border_color = Color("83deca")
	popup.add_theme_stylebox_override("panel",style)
	equipment.add_child(popup)
	var list := VBoxContainer.new()
	list.name = "List"
	list.add_theme_constant_override("separation",8)
	popup.add_child(list)
	var heading := Label.new()
	heading.text = "形を選択 / 配置で支払い / Esc取消"
	heading.add_theme_font_size_override("font_size",14)
	list.add_child(heading)
	for shape in state.Expansions.SHAPES:
		var why: String = state.expansion_offer_reason(turn,shape)
		var choice := Button.new()
		choice.name = "Expansion_"+shape
		choice.text = state.Expansions.NAMES[shape]+" %dG" % state.Expansions.SHAPES[shape].size()+(" / 選択" if why.is_empty() else "\n"+why)
		choice.disabled = not why.is_empty()
		choice.tooltip_text = "選択後にバッグへ配置。Escで取消。" if why.is_empty() else why
		choice.custom_minimum_size = Vector2(330,48)
		style_button(choice)
		choice.add_theme_font_size_override("font_size",14)
		choice.pressed.connect(select_expansion.bind(shape))
		list.add_child(choice)

func build_product(reward_list: Node, offer: Dictionary, state) -> void:
	var entry = offer.entry
	var reason: String = state.temporary_reason(turn) if offer.id == "field" else state.purchase_reason(turn,offer.id)
	var info := reward_info(entry)
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(0,70)
	reward_list.add_child(card)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("223648")
	style.set_corner_radius_all(5)
	card.add_theme_stylebox_override("panel",style)
	var layout := Control.new()
	layout.custom_minimum_size = Vector2(0,70)
	card.add_child(layout)
	var inspect := action_button(layout,"Inspect","",Rect2(0,0,244,70),inspect_offer.bind(str(offer.id)))
	for key in ["normal","hover","pressed"]: inspect.add_theme_stylebox_override(key,StyleBoxEmpty.new())
	inspect.tooltip_text = info.name+"\n"+info.desc+"\n"+reason
	inspect.focus_entered.connect(inspect_offer.bind(str(offer.id)))
	if not str(entry).begins_with("mod:"): add_footprint(inspect,entry,Rect2(10,10,26,24))
	else: text_at(inspect,"Mod","改",Rect2(10,10,26,24),17)
	text_at(inspect,"Name",info.name,Rect2(44,6,192,28),16)
	var effect := text_at(inspect,"Effect",info.desc if reason.is_empty() else reason,Rect2(10,39,230,24),13,Color("b2c6d8") if reason.is_empty() else Color("ffad83"))
	effect.autowrap_mode = TextServer.AUTOWRAP_OFF
	var caption: String = "無料確保" if offer.id == "field" else ("売切" if offer.sold else "%dG 購入" % offer.price)
	var buy := action_button(layout,"Claim",caption,Rect2(248,27,80,34),claim.bind(str(offer.id)),true)
	buy.disabled = not reason.is_empty()
	buy.tooltip_text = reason

func build_reserve(reserve: Node, state, build: Dictionary) -> void:
	var entries: Array = build.owned.filter(func(entry): return entry not in build.equipped)
	text_at(reserve,"Heading","控え %d / 8" % entries.size(),Rect2(16,8,142,26),18)
	text_at(reserve,"Capacity","未装備・クリックで詳細 / ドラッグで配置",Rect2(158,10,480,24),14,Color("91a7bc"))
	var tray := RelicTray.new()
	tray.name = "DropZone"
	tray.position = Vector2(0,0)
	tray.size = Vector2(1072,96)
	tray.on_drop = unequip_relic
	tray.add_theme_stylebox_override("panel",StyleBoxEmpty.new())
	reserve.add_child(tray)
	text_at(tray,"Hint","装備をこの欄へ戻すと解除",Rect2(746,10,310,24),14,Color("83deca"))
	# Retain the node path used by captures; scrolling is disabled and all 8 slots fit.
	var scroll := ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.position = Vector2(16,40)
	scroll.size = Vector2(1040,46)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	reserve.add_child(scroll)
	var list := HBoxContainer.new()
	list.name = "List"
	list.add_theme_constant_override("separation",8)
	scroll.add_child(list)
	for index in range(8):
		if index >= entries.size():
			var empty := RelicTray.new()
			empty.custom_minimum_size = Vector2(123,44)
			empty.on_drop = unequip_relic
			list.add_child(empty)
			text_at(empty,"Empty","%d   空き" % (index+1),Rect2(8,10,107,24),14,Color("657d90"))
			continue
		var entry = entries[index]
		var chip := RelicChip.new()
		chip.entry = entry
		chip.on_drag_start = select_entry
		chip.on_reserve_drop = unequip_relic
		chip.custom_minimum_size = Vector2(123,44)
		chip.tooltip_text = entry_info(entry).name+"\n"+entry_info(entry).desc
		style_button(chip)
		if latest_purchase != null and same_entry(entry,latest_purchase): chip.modulate = Color("b1ffe4")
		chip.pressed.connect(browse_entry.bind(entry))
		chip.focus_entered.connect(focus_entry.bind(entry))
		list.add_child(chip)
		add_footprint(chip,entry,Rect2(6,8,19,22))
		var caption := text_at(chip,"Caption",entry_info(entry).name,Rect2(29,12,89,22),13)
		caption.autowrap_mode = TextServer.AUTOWRAP_OFF

func refresh() -> void:
	$Root.visible = game.phase == "prepare"
	if not $Root.visible: return
	clear_preview()
	var state = game.match_state
	var build: Dictionary = state.builds[turn]
	if rendered_turn != turn:
		selected_detail = null
		selected_offer = ""
		selected_reward = false
		selected_expansion = ""
		placement_entry = null
		latest_purchase = null
		rendered_turn = turn
	state.sync_mod_product(turn)
	$Root/Panel/Content/Title.text = "携帯工房 / P%d ラウンド準備" % (turn+1)
	$Root/Panel/Content/Info.text = "準備 %d / 5本先取 / SCORE %d : %d / 所持金 %dG" % [state.stage,state.scores[0],state.scores[1],state.gold[turn]]
	$Root/Panel/Content/Info.tooltip_text = "相手の前ラウンド確定ビルド：" + " / ".join(game.roster.enemies(turn,game.players).map(func(player): return build_text(state.previous[game.players.find(player)])))
	var guns: Array = state.carried_guns(turn)
	var names: Array = guns.map(func(id): return str(Weapons.definition(id).name))
	var warnings: Array[String] = []
	if guns.is_empty(): warnings.append("武器未配置：近接のみで出撃")
	if state.temporary[turn] >= 0: warnings.append("未確保の無料品あり：出撃すると失います")
	$Root/Panel/Content/Ready.text = "近接のみで出撃" if guns.is_empty() else "この装備で出撃する"
	$Root/Panel/Content/Ready.disabled = state.ready[turn]
	var hp: float = game.players[turn].max_hp + Relics.additive_bonus(state.equipped_relics(turn),"hp_bonus")
	$Root/Panel/Content/Notice.text = "HP %s / %s   パルス %d   携行 %d丁   残金 %dG" % [str(hp),str(hp),game.players[turn].initial_pulses,guns.size(),state.gold[turn]]
	$Root/Panel/Content/Summary.text = " / ".join(warnings) if not warnings.is_empty() else "出撃装備："+" / ".join(names)
	$Root/Panel/Content/Summary.add_theme_color_override("font_color",Color("ffce88") if not warnings.is_empty() else Color("91a7bc"))
	$Root/Panel/Content/Summary.tooltip_text = " / ".join(warnings)+"\n"+build_text(build)+"\n武器順はグリッドの左上から。戦闘開始時に全快。"
	for child in $Root/Panel/Content/Cards.get_children():
		child.get_parent().remove_child(child)
		child.queue_free()
	var cards := $Root/Panel/Content/Cards
	var equipment := panel_at(cards,"Equipment",Rect2(0,0,676,490))
	var rewards := panel_at(cards,"Rewards",Rect2(692,0,380,490))
	var reserve := panel_at(cards,"Reserve",Rect2(0,506,1072,96))
	reserve.set_script(RelicTray)
	reserve.set("on_drop",unequip_relic)
	var details := panel_at(equipment,"Details",Rect2(396,0,280,490))
	text_at(equipment,"Heading","装備するもの",Rect2(20,16,206,32),22)
	text_at(equipment,"Capacity","使用 %d / %dマス" % [state.occupied_cells(turn).size(),state.capacity(turn)],Rect2(230,23,150,26),16,Color("83deca"))
	text_at(equipment,"Hint","ここに配置した装備で出撃します",Rect2(20,49,358,24),14,Color("91a7bc"))
	build_relic_grid(equipment,state,turn,build)
	text_at(equipment,"ExpansionHint","未開放マスは拡張で追加できます",Rect2(20,409,358,24),14,Color("91a7bc"))
	build_expansions(equipment,state)
	text_at(details,"Heading","アイテム詳細",Rect2(16,16,248,26),19)
	text_at(details,"Name","品をクリックして確認",Rect2(16,54,248,58),21,Color("83deca"))
	text_at(details,"Meta","クリックで詳細 / ドラッグで配置",Rect2(16,114,248,26),14,Color("91a7bc"))
	var detail_list := scroll_at(details,"TextScroll",Rect2(16,150,248,186))
	detail_description = Label.new()
	detail_description.name = "Description"
	detail_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_description.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_description.add_theme_font_size_override("font_size",16)
	detail_description.text = "購入した品は控えに入ります。\n\n控えからドラッグ、または詳細の「配置する」で装備してください。"
	detail_list.add_child(detail_description)
	text_at(details,"Status","詳細確認中は装備を動かしません",Rect2(16,342,248,48),14,Color("91a7bc"))
	action_button(details,"Place","配置する",Rect2(16,395,119,38),place_selected,true).hide()
	action_button(details,"Return","控えへ戻す",Rect2(143,395,121,38),return_detail).hide()
	action_button(details,"Buy","購入して控えへ",Rect2(16,395,248,38),buy_selected,true).hide()
	action_button(details,"Cancel","配置を取消",Rect2(16,442,119,36),cancel_placement).disabled = placement_entry == null and selected_expansion.is_empty()
	var discard_button := action_button(details,"Discard","売却 / 破棄",Rect2(143,442,121,36),discard_selected)
	discard_button.add_theme_color_override("font_color",Color("ffad83"))
	discard_button.tooltip_text = "完全に手放します。控えへ戻す操作とは異なります。"
	discard_button.hide()
	text_at(rewards,"Heading","ショップ",Rect2(18,16,165,32),22)
	text_at(rewards,"Remaining","%dG / 購入は任意・控えへ追加" % state.gold[turn],Rect2(18,49,344,24),14,Color("83deca"))
	var reroll := action_button(rewards,"Refresh","商品更新 2G",Rect2(218,12,144,36),refresh_shop)
	reroll.disabled = state.refreshed[turn] or state.gold[turn] < 2 or state.ready[turn]
	reroll.tooltip_text = "各準備1回。拡張・無料確保品は更新しません。"
	var reward_list := scroll_at(rewards,"Scroll",Rect2(18,77,344,397))
	reward_list.add_theme_constant_override("separation",8)
	var offers: Array = state.products[turn].duplicate(true)
	if state.temporary[turn] >= 0: offers.push_front({"id":"field","entry":state.temporary[turn],"price":0,"sold":false})
	for offer in offers: build_product(reward_list,offer,state)
	build_reserve(reserve,state,build)
	var selection_exists: bool = selected_detail != null and (offers.any(func(offer): return same_entry(offer.entry,selected_detail)) if selected_reward else selected_detail in build.owned)
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
	grid.position = Vector2(20,77)
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
				chip.focus_entered.connect(focus_entry.bind(entry))

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
