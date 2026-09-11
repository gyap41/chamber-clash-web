extends CanvasLayer
const Weapons = preload("res://scripts/catalog/weapon_catalog.gd")
const Relics = preload("res://scripts/catalog/relic_catalog.gd")
const RelicCard = preload("res://scripts/ui/relic_card.gd")
var slots: Array = []
var relic_cards: Array = []
const RELIC_HINTS := ["移動 +6%", "装填時間 -12%", "壁反射 +1回", "攻撃を1回防ぐ", "最大HP +1", "回避で6方向弾", "威力+8% / 弾速-10%", "満タン初射 +10%", "切替で1発装填", "パルスで6方向弾", "弾消しで回避短縮", "初反射で弾速+10%", "反射地点に停止弾", "空から装填で追加弾", "帰還→切替で威力増", "近接で消すと追加弾", "切替で弱い追射", "回避で予備弾を装填", "移動 +2%", "直接弾の威力 +2%", "直接弾の初速 +8%", "弾倉上限 +1", "最終射に合計 +0.15", "装填で回避待ち短縮", "回避待ち -6%", "回避後に移動加速", "近接待ち -8%", "弾消しで次の被害軽減", "被弾後に0.5回復・2回", "パルス後に移動加速", "切替初射の初速 +12%", "初反射で威力 +6%", "分裂破片の威力 +6%", "往復弾回収で1発装填", "宝箱開封 -10%"]
# Scroll within the existing HUD band so all equipped copies remain reachable.
const MAX_RELIC_CAPACITY := 36
const MAX_WEAPON_SLOTS := 8
func _ready() -> void:
	$Root/ResultActions/NextRound.pressed.connect(func(): get_parent().advance_result())
	$Root/ResultActions/CharacterSelect.pressed.connect(func(): get_parent().return_from_result(false))
	$Root/ResultActions/Title.pressed.connect(func(): get_parent().return_from_result(true))
	$Root/Status.tooltip_text = "弾の外周：橙=P1、青=P2。黄色の二重輪=高威力・設置・分裂・派生弾。紫の破線=仮装備を持つ相手の派生弾。レリック欄にカーソルを重ねると効果を確認できます。"
	for i in range(2):
		var cards: Array = []
		var parent := get_node("Root/Relics/P%d" % (i+1))
		var grid := parent.get_node("Grid")
		parent.remove_child(grid)
		var scroll := ScrollContainer.new()
		scroll.name = "Scroll"
		scroll.custom_minimum_size = Vector2(0,74)
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		parent.add_child(scroll)
		grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.add_child(grid)
		for n in range(MAX_RELIC_CAPACITY):
			var card := RelicCard.new()
			card.custom_minimum_size = Vector2(0,36)
			card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			card.mouse_filter = Control.MOUSE_FILTER_STOP
			var box := VBoxContainer.new()
			box.add_theme_constant_override("separation",0)
			box.mouse_filter = Control.MOUSE_FILTER_IGNORE
			card.add_child(box)
			for font_size in [14,12]:
				var label := Label.new()
				label.add_theme_font_size_override("font_size",font_size)
				label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
				label.mouse_filter = Control.MOUSE_FILTER_IGNORE
				box.add_child(label)
			grid.add_child(card)
			cards.append(card)
		relic_cards.append(cards)
		var row: Array = []
		for n in range(MAX_WEAPON_SLOTS):
			var button := Button.new()
			button.custom_minimum_size = Vector2(129,86)
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			button.focus_mode = Control.FOCUS_NONE
			button.expand_icon = true
			button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
			button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
			button.add_theme_constant_override("icon_max_width",45)
			button.add_theme_font_size_override("font_size",11)
			button.pressed.connect(func(): get_parent().equip_slot(i,n))
			get_node("Root/Loadouts/P%d" % (i+1)).add_child(button)
			row.append(button)
		slots.append(row)
	# Reconstructed 2026-09-08 alongside main.gd/player.gd: the mute toggle itself only flips
	# Sound.enabled (which is what plays/suppresses the "toggle" cue, see sound.gd's own
	# set_enabled()); refresh() below keeps the button's label in sync every frame, including
	# after reset_round() re-mutes audio for the new round.
	$SoundControls/Toggle.pressed.connect(func():
		var audio = get_parent().sound
		audio.set_enabled(not audio.enabled)
	)
func refresh(players: Array, remaining: float, paused: bool, result: String, scores: Array, phase: String) -> void:
	$Root/ResultActions.visible = not result.is_empty()
	var supply = get_parent().supplies
	$Root/SupplyNotice.text = supply.notice if phase == "play" and supply.notice_time > 0 and not paused else ""
	var p = players[0]
	var q = players[1]
	$Root/HP1.refresh(p.state.hp,p.state.max_hp)
	$Root/HP2.refresh(q.state.hp,q.state.max_hp)
	$SoundControls/Toggle.text = "音 ON" if get_parent().sound.enabled else "音 OFF"
	var p2_label := "P2 (CPU)" if q.is_cpu else "P2"
	# Operation hints used to live here every frame; they now live on the title screen (see
	# scripts/title.gd) so the in-match HUD only shows live status. The P2 line is kept only
	# for the local-keyboard fallback (is_cpu==false) — CPU matches (the normal path from the
	# title screen) show "P2はCPUが自動操作" instead, same as before.
	$Root/Status.text = "P1 HP %.1f/%.0f  %s %d/%d  |  %02d sec  |  %s HP %.1f/%.0f  %s %d/%d\n%s   ESC停止   SCORE %d : %d（5本先取）" % [p.state.hp,p.state.max_hp,p.definition().name,p.weapon().clip,p.weapon().reserve,maxi(0,int(remaining)),p2_label,q.state.hp,q.state.max_hp,q.definition().name,q.weapon().clip,q.weapon().reserve,"P2はCPUが自動操作" if q.is_cpu else "P2 矢印 / L射撃 / SHIFT回避 / N近接 / P装填 / K切替 / H交換 / Oパルス",scores[0],scores[1]]
	$Root/Status.text += "   PULSE %d : %d" % [p.state.pulses,q.state.pulses]
	var inset: float = get_parent().arena_inset()
	if inset > 0: $Root/Status.text += "   危険地帯：外周%dpxが継続ダメージ" % ceili(inset)
	var match_over: bool = scores.max() >= preload("res://scripts/catalog/shop_catalog.gd").WIN_TARGET
	$Root/ResultActions/NextRound.visible = not match_over
	$Root/ResultActions/NextRound.text = "再戦する  [Enter]" if result == "DRAW" else "次のラウンドの準備へ  [Enter]"
	$Root/ResultActions/CharacterSelect.visible = match_over
	$Root/ResultActions/Title.visible = match_over
	if paused:
		$Root/Message.text = "PAUSED"
	elif result == "":
		$Root/Message.text = ""
	elif match_over:
		$Root/Message.text = "試合終了！ %s\n最終スコア  %d - %d" % [result,scores[0],scores[1]]
	elif result == "DRAW":
		$Root/Message.text = "引き分け\n同じ装備で再戦します"
	else:
		$Root/Message.text = "ラウンド終了  %s\nスコア  %d - %d" % [result,scores[0],scores[1]]
	for i in range(2):
		refresh_relics(i,players[i])
		for n in range(MAX_WEAPON_SLOTS):
			var button: Button = slots[i][n]
			var player = players[i]
			# P8z：携行していないスロットは「空き」ではなく非表示にする。準備画面のグリッドに
			# 何丁置いたかがそのまま並ぶので、埋まっていない枠を見せる意味がなくなった。
			button.visible = n < player.inventory.size()
			button.disabled = not button.visible or phase != "play" or paused or player.is_cpu
			if not button.visible:
				button.icon = null
				button.modulate = Color.WHITE
				continue
			var w: Dictionary = player.inventory[n]
			# P5: resolved_definition() folds in this weapon's active mod branch (if any), so the
			# HUD name/tooltip surface it — part of P5's "改造＋レリックの...表示...を検証する".
			var g: Dictionary = player.resolved_definition(w.id)
			var mod_tag: String = "　⚙"+str(g.mod_name) if g.has("mod_name") else ""
			button.icon = Weapons.art(w.id)
			var active: bool = player.state.gun == n
			button.modulate = Color("ffd091") if active else Color.WHITE
			button.text = "%d %s\n%s%s\n%d / %d%s" % [n+1,"装備中" if active else "",g.name,mod_tag,w.clip,w.reserve," 装填中" if active and player.state.reload > 0 else (" 散弾" if w.mode == 1 else "")]
			button.tooltip_text = g.desc + ("\n改造："+str(g.mod_name) if g.has("mod_name") else "") + "\n" + Weapons.stats_text(g)

func refresh_relics(index: int, player) -> void:
	get_node("Root/Relics/P%d/Heading" % (index+1)).text = "P%d レリック %d個 · バッグ%dマス · スクロールで詳細" % [index+1,player.relics.size(),player.relic_capacity]
	for slot in range(MAX_RELIC_CAPACITY):
		var card: PanelContainer = relic_cards[index][slot]
		card.visible = slot < mini(player.relic_capacity,maxi(6,player.relics.size()))
		if not card.visible: continue
		var title: Label = card.get_child(0).get_child(0)
		var hint: Label = card.get_child(0).get_child(1)
		var id: int = player.relics[slot] if slot < player.relics.size() else -1
		# Rebuild styles only when equipment changes, not on every physics frame.
		var temporary: bool = id >= 0 and slot == player.temporary_relic_slot and id == player.temporary_relic
		var style_key := "%d/%s/%d" % [id,temporary,player.relic_capacity]
		if card.get_meta("style_key","") != style_key:
			card.set_meta("style_key",style_key)
			var style := StyleBoxFlat.new()
			style.bg_color = Color("352940") if temporary else Color("202930")
			style.border_color = Color("e6a0ff") if temporary else (Color(Relics.definition(id).color) if id >= 0 else Color("465057"))
			style.set_border_width_all(1)
			style.border_width_left = 4
			style.content_margin_left = 6
			style.content_margin_right = 3
			card.add_theme_stylebox_override("panel",style)
		if id < 0:
			title.text = "空き枠"
			hint.text = "準備画面で装備"
			card.tooltip_text = title.text
			card.modulate = Color(1,1,1,.4)
			continue
		card.modulate = Color.WHITE
		var relic: Dictionary = Relics.definition(id)
		title.text = ("仮 " if temporary else "") + str(relic.name)
		title.modulate = Color(relic.color)
		hint.text = RELIC_HINTS[id]
		if id == 3 and player.state.shield > 0: hint.text = "再使用まで %d秒" % ceili(player.state.shield)
		if id == 14 and (player.state.return_battery_charge or player.state.return_battery_armed): hint.text = "充電済み / " + ("次射を強化" if player.state.return_battery_armed else "切替で発動")
		if id == 15 and player.state.residual_heat_charge: hint.text = "次の射撃に追加弾！"
		if id == 13 and player.state.empty_casing_charge: hint.text = "次の初射に追加弾！"
		card.tooltip_text = ("【このラウンドの仮装備】\n" if temporary else "【装備中】\n") + str(relic.name) + "\n" + str(relic.desc)

		if Relics.stackable(id):
			var count: int = player.relics.count(id)
			var total := "同種%d個 / 合計%s" % [count,Relics.stack_summary(id,count)]
			hint.text += " · 同種%d個" % count
			card.tooltip_text += "\n" + total
