extends CanvasLayer
const Weapons = preload("res://scripts/catalog/weapon_catalog.gd")
var slots: Array = []
func _ready() -> void:
	for i in range(2):
		var row: Array = []
		for n in range(4):
			var button := Button.new()
			button.custom_minimum_size = Vector2(129,115)
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			button.focus_mode = Control.FOCUS_NONE
			button.expand_icon = true
			button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
			button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
			button.add_theme_constant_override("icon_max_width",65)
			button.add_theme_font_size_override("font_size",12)
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
	$Root/Status.text = "P1 HP %.1f/%.0f  %s %d/%d  |  %02d sec  |  %s HP %.1f/%.0f  %s %d/%d\n%s   ESC停止   SCORE %d : %d（3本先取）" % [p.state.hp,p.state.max_hp,p.definition().name,p.weapon().clip,p.weapon().reserve,maxi(0,int(remaining)),p2_label,q.state.hp,q.state.max_hp,q.definition().name,q.weapon().clip,q.weapon().reserve,"P2はCPUが自動操作" if q.is_cpu else "P2 矢印 / L射撃 / SHIFT回避 / N近接 / P装填 / K切替 / H交換 / Oパルス",scores[0],scores[1]]
	$Root/Status.text += "   PULSE %d : %d" % [p.state.pulses,q.state.pulses]
	var inset: float = get_parent().arena_inset()
	if inset > 0: $Root/Status.text += "   危険地帯：外周%dpxが継続ダメージ" % ceili(inset)
	# A round win (result != "") only ends the whole match once someone's score reaches 3 —
	# reset_round() silently zeroes scores back to 0-0 in that case (see main.gd). That was
	# easy to miss because the message read the same as any other round win, so a completed
	# match didn't visibly look different from "on to the next round". Make the match-complete
	# case visually distinct instead of just swapping the trailing hint text.
	var match_over: bool = scores.max() >= 3
	if paused:
		$Root/Message.text = "PAUSED"
	elif result == "":
		$Root/Message.text = ""
	elif match_over:
		$Root/Message.text = "マッチ終了！ %s（最終 %d - %d） 　ENTER で新しい試合" % [result,scores[0],scores[1]]
	else:
		$Root/Message.text = "%s（%d - %d）　ENTER で次ラウンドの準備" % [result,scores[0],scores[1]]
	for i in range(2):
		var names: Array[String] = []
		for id in players[i].relics:
			var rname: String = players[i].Relics.definition(id).name
			if id == 3 and players[i].state.shield > 0: rname += "（%ds）" % ceili(players[i].state.shield)
			names.append(("[仮] " if id == players[i].temporary_relic else "")+rname)
		get_node("Root/Relics/P%d" % (i+1)).text = "P%d レリック %d/%d\n%s" % [i+1,names.size(),players[i].relic_capacity,"\n".join([" / ".join(names.slice(0,3))," / ".join(names.slice(3,6))]) if not names.is_empty() else "なし"]
		for n in range(4):
			var button: Button = slots[i][n]
			var player = players[i]
			button.disabled = n >= player.inventory.size() or phase != "play" or paused or player.is_cpu
			if n >= player.inventory.size():
				button.text = "空き %d" % (n+1)
				button.icon = null
				button.modulate = Color.WHITE
				continue
			var w: Dictionary = player.inventory[n]
			var g := Weapons.definition(w.id)
			button.icon = Weapons.art(w.id)
			var active: bool = player.state.gun == n
			button.modulate = Color("ffd091") if active else Color.WHITE
			button.text = "%d %s\n%s\n%d / %d%s" % [n+1,"装備中" if active else "",g.name,w.clip,w.reserve," 装填中" if active and player.state.reload > 0 else (" 散弾" if w.mode == 1 else "")]
			button.tooltip_text = g.desc
