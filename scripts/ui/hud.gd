extends CanvasLayer
const Weapons = preload("res://scripts/catalog/weapon_catalog.gd")
const Relics = preload("res://scripts/catalog/relic_catalog.gd")
const Characters = preload("res://scripts/catalog/character_catalog.gd")
const RelicIcon = preload("res://scripts/ui/hud_relic_icon.gd")
const Action = preload("res://scripts/ui/hud_action.gd")
const Art = preload("res://scripts/ui/hud_assets.gd")
const MAX_RELIC_CAPACITY := 36
const MAX_WEAPON_SLOTS := 8
var slots: Array = []
var relic_cards: Array = []
var compact_relics: Array = []
var actions: Array = []
var local_mode := false
var layout_initialized := false
var reload_max := [0.0,0.0]

func box(parent: Node, title: String, rect: Rect2) -> Panel:
	var panel := Panel.new()
	panel.name = title
	panel.position = rect.position
	panel.size = rect.size
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = Color("192126")
	style.border_color = Color("44535b")
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	panel.add_theme_stylebox_override("panel",style)
	var background := Art.optional_texture("panel")
	if background:
		var textured := StyleBoxTexture.new()
		textured.texture = background
		textured.texture_margin_left = 8
		textured.texture_margin_top = 8
		textured.texture_margin_right = 8
		textured.texture_margin_bottom = 8
		panel.add_theme_stylebox_override("panel",textured)
	parent.add_child(panel)
	return panel

func label(parent: Node, title: String, rect: Rect2, font_size: int = 16) -> Label:
	var item := Label.new()
	item.name = title
	item.position = rect.position
	item.size = rect.size
	item.add_theme_font_size_override("font_size",font_size)
	item.add_theme_color_override("font_color",Color("e5edf0"))
	item.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(item)
	return item

func button(parent: Node, title: String, rect: Rect2, caption: String, callback: Callable) -> Button:
	var item := Button.new()
	item.name = title
	item.position = rect.position
	item.size = rect.size
	item.text = caption
	item.focus_mode = Control.FOCUS_NONE
	item.add_theme_font_size_override("font_size",14)
	item.pressed.connect(callback)
	parent.add_child(item)
	return item

func toggle_details() -> void:
	var game = get_parent()
	if game.phase != "play" or not game.result.is_empty(): return
	game.clear_action_inputs()
	game.paused = not game.paused
	refresh(game.players,game.remaining,game.paused,game.result,game.scores,game.phase)

func _ready() -> void:
	$Root/ResultActions/NextRound.pressed.connect(func(): get_parent().advance_result())
	$Root/ResultActions/CharacterSelect.pressed.connect(func(): get_parent().return_from_result(false))
	$Root/ResultActions/Title.pressed.connect(func(): get_parent().return_from_result(true))
	$SoundControls/Toggle.pressed.connect(func(): get_parent().sound.set_enabled(not get_parent().sound.enabled))
	box($Root,"Header",Rect2(12,6,1096,80))
	# Existing HP node paths remain stable for combat feedback consumers.
	for i in range(2):
		var x := 28 if i == 0 else 736
		label($Root,"Name%d" % i,Rect2(x,10,240,25),20)
		var hp = get_node("Root/HP%d" % (i+1))
		hp.position = Vector2(x,40)
		hp.size = Vector2(280,16)
		hp.move_to_front()
		label($Root,"Health%d" % i,Rect2(x,58,130,22),17)
	label($Root,"Round",Rect2(440,8,240,19),14).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label($Root,"Timer",Rect2(440,24,240,39),34).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label($Root,"Score",Rect2(440,62,240,20),15).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button($Root,"Pause",Rect2(1020,44,76,30),"ESC 停止",toggle_details)
	box($Root,"Dock",Rect2(12,700,1096,92))
	$Root/Loadouts.move_to_front()
	$Root/LocalStatus.move_to_front()
	var modal_background := box($Root/Relics,"Background",Rect2(0,0,1072,348))
	modal_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$Root/Relics.move_child(modal_background,0)
	label($Root/Relics,"Title",Rect2(16,10,650,30),20).text = "一時停止  ·  所持レリック"
	button($Root/Relics,"Sound",Rect2(704,4,140,30),"音 切替",func(): $SoundControls/Toggle.pressed.emit())
	for i in range(2):
		var active := Control.new()
		active.name = "Active%d" % i
		active.mouse_filter = Control.MOUSE_FILTER_IGNORE
		$Root.add_child(active)
		label(active,"Name",Rect2(0,0,214,21),15)
		label(active,"Ammo",Rect2(0,22,214,35),24)
		label(active,"State",Rect2(0,60,214,18),12)
		var weapon_art := TextureRect.new()
		weapon_art.name = "Art"
		weapon_art.position = Vector2(0,25)
		weapon_art.size = Vector2(40,28)
		weapon_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		weapon_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		weapon_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		active.add_child(weapon_art)
		var progress := ProgressBar.new()
		progress.name = "Reload"
		progress.position = Vector2(0,57)
		progress.size = Vector2(210,4)
		progress.show_percentage = false
		progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
		active.add_child(progress)
		var row: Array = []
		var loadout = get_node("Root/Loadouts/P%d" % (i+1))
		for n in range(MAX_WEAPON_SLOTS):
			var slot := Button.new()
			slot.custom_minimum_size = Vector2(44,56)
			slot.focus_mode = Control.FOCUS_NONE
			slot.expand_icon = true
			slot.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
			slot.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
			slot.add_theme_constant_override("icon_max_width",30)
			slot.add_theme_font_size_override("font_size",12)
			slot.pressed.connect(func(): get_parent().equip_slot(i,n))
			loadout.add_child(slot)
			row.append(slot)
		slots.append(row)
		var cards: Array = []
		var parent = get_node("Root/Relics/P%d" % (i+1))
		var grid = parent.get_node("Grid")
		parent.remove_child(grid)
		var scroll := ScrollContainer.new()
		scroll.name = "Scroll"
		scroll.custom_minimum_size = Vector2(0,236)
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		parent.add_child(scroll)
		scroll.add_child(grid)
		for n in range(MAX_RELIC_CAPACITY):
			var card := RelicIcon.new()
			card.custom_minimum_size = Vector2(60,60)
			card.mouse_filter = Control.MOUSE_FILTER_STOP
			grid.add_child(card)
			cards.append(card)
		relic_cards.append(cards)
		var compact: Array = []
		for n in range(4):
			var card := RelicIcon.new()
			card.name = "Compact%d_%d" % [i,n]
			card.size = Vector2(28,28)
			card.mouse_filter = Control.MOUSE_FILTER_STOP
			$Root.add_child(card)
			compact.append(card)
		compact_relics.append(compact)
	for n in range(3):
		var action := Action.new()
		action.position = Vector2(640+n*76,710)
		action.size = Vector2(72,72)
		$Root.add_child(action)
		action.configure(["dodge","melee","pulse"][n],["SPACE","右クリック","Q"][n],["回避","近接","パルス"][n])
		actions.append(action)
	button($Root,"RelicButton",Rect2(886,751,206,30),"レリック",toggle_details)
	button($Root,"EnemyRelics",Rect2(1018,9,78,30),"一覧",toggle_details)
	$Root/Relics.move_to_front()
	$Root/Message.move_to_front()
	$Root/ResultActions.move_to_front()
	button($Root/Relics,"Close",Rect2(878,0,166,30),"閉じる / ESC",toggle_details)

func layout(is_local: bool) -> void:
	if layout_initialized and local_mode == is_local: return
	layout_initialized = true
	local_mode = is_local
	for i in range(2):
		var active = get_node("Root/Active%d" % i)
		active.visible = i == 0 or local_mode
		active.position = Vector2(26,704+i*44) if local_mode else Vector2(26,706)
		active.get_node("Name").visible = not local_mode
		active.get_node("State").visible = not local_mode
		active.get_node("Ammo").position.y = 0 if local_mode else 22
		active.get_node("Ammo").position.x = 0 if local_mode else 46
		active.get_node("Ammo").size.x = 214 if local_mode else 168
		active.get_node("Art").visible = not local_mode
		active.get_node("Ammo").add_theme_font_size_override("font_size",16 if local_mode else 24)
		active.get_node("Reload").position.y = 34 if local_mode else 57
		var row = get_node("Root/Loadouts/P%d" % (i+1))
		row.visible = i == 0 or local_mode
		row.position = Vector2(244,704+i*44) if local_mode else Vector2(244,717)
		row.size = Vector2(380,40 if local_mode else 56)
		for slot in slots[i]:
			slot.custom_minimum_size = Vector2(44,40 if local_mode else 56)
			slot.add_theme_constant_override("icon_max_width",16 if local_mode else 30)
			slot.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER if local_mode else VERTICAL_ALIGNMENT_TOP
			slot.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT if local_mode else HORIZONTAL_ALIGNMENT_CENTER
			slot.reset_size()
		row.reset_size()
	for action in actions: action.visible = not local_mode
	$Root/LocalStatus.visible = local_mode

func refresh(players: Array, remaining: float, paused: bool, result: String, scores: Array, phase: String) -> void:
	var game = get_parent()
	$Root.visible = phase != "prepare"
	$Root/ResultActions.visible = not result.is_empty()
	$Root/Relics.visible = paused and result.is_empty() and phase == "play"
	$Root/Message.text = ""
	$Root/Pause.text = "ESC 再開" if paused else "ESC 停止"
	layout(not players[1].is_cpu)
	$SoundControls/Toggle.text = "音 ON" if game.sound.enabled else "音 OFF"
	$SoundControls/Toggle.visible = phase == "prepare"
	$Root/Relics/Sound.text = $SoundControls/Toggle.text
	$Root/Round.text = "ROUND %d" % game.match_state.stage
	$Root/Timer.text = "%02d 秒" % maxi(0,ceili(remaining))
	$Root/Timer.modulate = Color("ff9d83") if remaining <= 10 else Color.WHITE
	$Root/Score.text = "%d  —  %d   ·   5本先取" % [scores[0],scores[1]]
	$Root/Status.text = "安全地帯 縮小中" if game.arena_inset() > 0 else ""
	var supply = game.supplies
	$Root/SupplyNotice.text = supply.notice if phase == "play" and supply.notice_time > 0 and not paused and result.is_empty() else ""
	if $Root/SupplyNotice.text.begins_with("選んだ主力で開戦"):
		$Root/SupplyNotice.text = "戦闘開始"
	var match_over: bool = scores.max() >= preload("res://scripts/catalog/shop_catalog.gd").WIN_TARGET
	$Root/ResultActions/NextRound.visible = not match_over
	$Root/ResultActions/NextRound.text = "再戦する  [Enter]" if result == "DRAW" else "次のラウンドの準備へ  [Enter]"
	$Root/ResultActions/CharacterSelect.visible = match_over
	$Root/ResultActions/Title.visible = match_over
	if not result.is_empty():
		$Root/Message.text = ("試合終了！ " if match_over else "ラウンド終了  ") + result + "\nスコア  %d - %d" % [scores[0],scores[1]]
		if result == "DRAW": $Root/Message.text = "引き分け\n同じ装備で再戦します"
	for i in range(2):
		var p = players[i]
		var tag := "CPU" if p.is_cpu else "P%d" % (i+1)
		var char_name: String = Characters.definition(p.char_id).name if p.char_id >= 0 else ""
		get_node("Root/Name%d" % i).text = tag + "  " + char_name
		get_node("Root/Name%d" % i).modulate = Color("f39545") if i == 0 else Color("64b5ee")
		get_node("Root/HP%d" % (i+1)).refresh(p.state.hp,p.state.max_hp)
		get_node("Root/Health%d" % i).text = "%.1f / %.0f" % [p.state.hp,p.state.max_hp]
		get_node("Root/Health%d" % i).modulate = Color("ff9d83") if p.state.hp <= p.state.max_hp*.25 else Color.WHITE
		var active = get_node("Root/Active%d" % i)
		active.get_node("Name").text = p.definition().name
		active.get_node("Art").texture = Weapons.art(p.weapon().id) if p.has_weapon() else null
		active.get_node("Ammo").text = ("P%d  %d / %d" % [i+1,p.weapon().clip,p.weapon().reserve] if local_mode else "%d · 予備%d" % [p.weapon().clip,p.weapon().reserve]) if p.has_weapon() else "丸腰"
		active.get_node("Ammo").tooltip_text = "装弾数 / 予備弾数"
		var wait: float = p.state.reload
		if local_mode and wait > 0: active.get_node("Ammo").text += " 装填"
		if wait <= 0: reload_max[i] = 0.0
		else: reload_max[i] = maxf(reload_max[i],wait)
		active.get_node("Reload").visible = wait > 0
		active.get_node("Reload").value = (1.0-wait/reload_max[i])*100 if wait > 0 else 0
		active.get_node("State").text = "装填中 %.1f秒" % wait if wait > 0 else ("R 装填  ·  E / ホイール 切替" if p.has_weapon() else "近接攻撃で戦えます")
		for n in range(MAX_WEAPON_SLOTS):
			var slot: Button = slots[i][n]
			slot.visible = n < p.inventory.size()
			slot.disabled = not slot.visible or phase != "play" or paused or not result.is_empty() or p.is_cpu
			if not slot.visible: continue
			var w: Dictionary = p.inventory[n]
			var g: Dictionary = p.resolved_definition(w.id)
			slot.icon = Weapons.art(w.id)
			slot.text = str(n+1)
			slot.modulate = Color("ffc980") if p.state.gun == n else Color("aebdc5")
			slot.tooltip_text = "%s\n弾倉 %d / 予備 %d\n%s" % [g.name,w.clip,w.reserve,g.desc]
			if g.has("mod_name"): slot.tooltip_text += "\n改造：" + str(g.mod_name)
		refresh_relics(i,p)
	var p = players[0]
	var usable: bool = phase == "play" and not paused and result.is_empty() and p.state.hp > 0
	actions[0].refresh(p.state.dodge,p.dodge_cooldown*(p.relic_value(24,"dodge_ratio") if 24 in p.relics else 1.0),usable and p.state.dodge <= 0,"%.1f秒" % p.state.dodge if p.state.dodge > 0 else "回避")
	actions[1].refresh(p.state.melee,p.melee_cooldown*(p.relic_value(26,"melee_ratio") if 26 in p.relics else 1.0),usable and p.state.melee <= 0 and p.state.reload <= 0 and p.state.roll <= 0,"%.1f秒" % p.state.melee if p.state.melee > 0 else "近接")
	actions[2].refresh(0,1,usable and p.state.pulses > 0,"パルス %d" % p.state.pulses)
	$Root/LocalStatus.text = "P1  回避 %.1f  近接 %.1f  Q %d\nP2  回避 %.1f  近接 %.1f  O %d" % [p.state.dodge,p.state.melee,p.state.pulses,players[1].state.dodge,players[1].state.melee,players[1].state.pulses]

func relic_state(player, id: int) -> Dictionary:
	var wait := 0.0
	var charged := false
	if id == 3: wait = player.state.shield
	if id == 13: charged = player.state.empty_casing_charge
	if id == 14: charged = player.state.return_battery_charge or player.state.return_battery_armed
	if id == 15: charged = player.state.residual_heat_charge
	var timers := {16:"echo_holster_cd",23:"cool_grip_cd",27:"shell_cd",30:"sight_cd",33:"reel_cd"}
	if timers.has(id): wait = player.state.get(timers[id],0.0)
	if id == 27: charged = player.state.get("shell_time",0.0) > 0
	if id == 28: charged = player.state.get("aid_time",0.0) > 0
	return {"seconds":ceili(wait),"charged":charged}

func refresh_relics(index: int, player) -> void:
	get_node("Root/Relics/P%d/Heading" % (index+1)).text = "P%d レリック %d個  ·  アイコンに重ねて効果を確認" % [index+1,player.relics.size()]
	var important: Array = []
	var seen: Array = []
	for slot in range(MAX_RELIC_CAPACITY):
		var card = relic_cards[index][slot]
		card.visible = slot < player.relics.size()
		if not card.visible: continue
		var id: int = player.relics[slot]
		var temporary: bool = slot == player.temporary_relic_slot and id == player.temporary_relic
		var state := relic_state(player,id)
		var count: int = player.relics.count(id)
		card.configure(id,1,temporary,state.seconds,state.charged)
		var relic: Dictionary = Relics.definition(id)
		card.tooltip_text = ("【このラウンドの仮装備】\n" if temporary else "【装備中】\n") + str(relic.name) + "\n" + str(relic.desc)
		if Relics.stackable(id): card.tooltip_text += "\n同種%d個 / 合計%s" % [count,Relics.stack_summary(id,count)]
		if state.seconds > 0: card.tooltip_text += "\n再使用まで %d秒" % state.seconds
		if state.charged: card.tooltip_text += "\n効果待機中"
		if temporary or state.charged or state.seconds > 0: important.append(slot)
		if not seen.has(id): seen.append(id)
	# Prioritize temporary and charged effects, aggregate passive opponent copies.
	important.sort_custom(func(a,b): return priority(player,a) > priority(player,b))
	if index == 1:
		for id in seen:
			var slot: int = player.relics.find(id)
			if not important.has(slot): important.append(slot)
	var shown_ids: Array = []
	var selected: Array = []
	for slot in important:
		var id: int = player.relics[slot]
		if shown_ids.has(id): continue
		shown_ids.append(id)
		selected.append(slot)
	for n in range(4):
		var card = compact_relics[index][n]
		card.visible = n < selected.size() and (index == 1 or n < 2)
		card.position = Vector2(876+n*32,57) if index == 1 else Vector2(890+n*36,714)
		if not card.visible: continue
		var slot: int = selected[n]
		var source = relic_cards[index][slot]
		card.configure(source.relic_id,player.relics.count(source.relic_id),source.temporary,source.seconds,source.charged)
		card.tooltip_text = source.tooltip_text
	if index == 0: $Root/RelicButton.text = "レリック %d  ·  一覧 / 停止" % player.relics.size()
	else: $Root/EnemyRelics.text = "一覧 %d" % player.relics.size()

func priority(player, slot: int) -> int:
	var id: int = player.relics[slot]
	var state := relic_state(player,id)
	return (100 if slot == player.temporary_relic_slot else 0) + (20 if state.charged else 0) + (10 if state.seconds > 0 else 0)
