extends CanvasLayer
const Widgets = preload("res://scripts/ui/hud_widgets.gd")
const View = preload("res://scripts/ui/combat_hud_view.gd")
const HealthBar = preload("res://scripts/ui/hp_bar.gd")
const WeaponPanel = preload("res://scripts/ui/hud_weapon_panel.gd")
const WeaponSlot = preload("res://scripts/ui/hud_weapon_slot.gd")
const Action = preload("res://scripts/ui/hud_action.gd")
const MAX_WEAPON_SLOTS := 8
const HudSkin = preload("res://scripts/ui/exploration_hud_skin.gd")
var shown_hp: float = -1
var shown_weapon: int = -1
signal bag_requested
signal map_requested
signal slot_requested(index: int)
signal pause_requested
signal retry_requested
signal title_requested
signal sound_requested
var slots: Array = []
var actions: Array = []
var shown_gold := -1
func _ready() -> void:
	var canvas := Control.new()
	canvas.name = "Root"
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(canvas)
	var decor := HudSkin.new()
	decor.name = "Decor"
	canvas.add_child(decor)
	var menu := Widgets.box(canvas,"PauseMenu",Rect2(400,240,320,265))
	menu.hide()
	Widgets.box(canvas,"Header",Rect2(22,22,268,66))
	Widgets.label(canvas,"Name",Rect2(28,10,280,25),20).text = "リナ"
	var health := HealthBar.new()
	health.name = "HP"
	health.position = Vector2(53,41)
	health.size = Vector2(204,22)
	health.segment_color = Color("c66854")
	health.show_segments = true
	health.mouse_filter = Control.MOUSE_FILTER_STOP
	canvas.add_child(health)
	Widgets.label(canvas,"Health",Rect2(28,58,160,22),17)
	var gold := Widgets.label(canvas,"Gold",Rect2(334,36,136,30),21)
	gold.add_theme_color_override("font_color",Color("ffd35a"))
	Widgets.label(canvas,"Heading",Rect2(350,12,440,26),20)
	Widgets.label(canvas,"Status",Rect2(350,47,470,24),15)
	Widgets.button(canvas,"Bag",Rect2(1000,22,42,45),"",func(): bag_requested.emit())
	Widgets.button(canvas,"Pause",Rect2(1048,22,42,45),"",func(): pause_requested.emit())
	Widgets.button(canvas,"Title",Rect2(446,430,228,44),"タイトルへ",func(): title_requested.emit())
	Widgets.box(canvas,"Dock",Rect2(396,700,708,92))
	var active := WeaponPanel.new()
	active.compact = true
	active.name = "Active"
	active.position = Vector2(802,690)
	canvas.add_child(active)
	var loadout := HBoxContainer.new()
	loadout.name = "Loadout"
	loadout.position = Vector2(410,726)
	loadout.size = Vector2(373,48)
	loadout.add_theme_constant_override("separation",3)
	canvas.add_child(loadout)
	for i in range(MAX_WEAPON_SLOTS):
		var slot := WeaponSlot.new()
		slot.compact = true
		slot.slot_index = i
		slot.slot_requested.connect(func(index): slot_requested.emit(index))
		loadout.add_child(slot)
		slots.append(slot)
	for i in range(3):
		var action := Action.new()
		action.compact = true
		action.position = Vector2(936+i*53,620)
		action.size = Vector2(48,56)
		canvas.add_child(action)
		action.configure(["dodge","melee","pulse"][i],["SPACE","右クリック","Q"][i],["回避","近接","パルス"][i])
		actions.append(action)
	Widgets.button(canvas,"Sound",Rect2(446,320,228,40),"SE ON",func(): sound_requested.emit())
	var help = Widgets.label(canvas,"Help",Rect2(24,622,730,58),16)
	Widgets.button(canvas,"Map",Rect2(952,22,42,45),"",func(): map_requested.emit())
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.add_theme_color_override("font_shadow_color",Color.BLACK)
	help.add_theme_constant_override("shadow_offset_x",2)
	help.add_theme_constant_override("shadow_offset_y",2)
	var outcome := Widgets.box(canvas,"Outcome",Rect2(310,280,500,150))
	Widgets.label(outcome,"Message",Rect2(16,20,468,36),26).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Widgets.button(outcome,"Retry",Rect2(140,82,220,46),"もう一度挑戦",func(): retry_requested.emit())
	outcome.hide()
	Widgets.label(canvas,"Boss",Rect2(434,23,400,26),18).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var boss_health := HealthBar.new()
	boss_health.name = "BossHP"
	boss_health.position = Vector2(434,55)
	boss_health.size = Vector2(400,8)
	boss_health.mouse_filter = Control.MOUSE_FILTER_STOP
	canvas.add_child(boss_health)

	Widgets.button(canvas,"Resume",Rect2(446,268,228,40),"再開",func(): pause_requested.emit())
	Widgets.button(canvas,"Music",Rect2(446,375,228,40),"",func():
		var music = get_node("/root/Music")
		music.set_enabled(not music.enabled)
		$Root/Music.text = "BGM ON" if music.enabled else "BGM OFF")
	for key in ["Name","Health","Heading","Status"]: canvas.get_node(key).hide()
	for key in ["Header","Dock","PauseMenu"]:
		canvas.get_node(key).add_theme_stylebox_override("panel",StyleBoxEmpty.new())
		canvas.get_node(key).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for key in ["Map","Bag","Pause"]:
		var button: Button = canvas.get_node(key)
		button.add_theme_stylebox_override("normal",StyleBoxEmpty.new())
		button.add_theme_stylebox_override("disabled",StyleBoxEmpty.new())
		var hover := StyleBoxFlat.new()
		hover.bg_color = Color(.5,1,.8,.16)
		hover.set_corner_radius_all(6)
		button.add_theme_stylebox_override("hover",hover)
		button.add_theme_stylebox_override("pressed",hover)
	$Root/Map.tooltip_text = "階層マップ（M）"
	$Root/Bag.tooltip_text = "バッグ（Tab）"
	$Root/Pause.tooltip_text = "一時停止 / 再開（Esc）"

	for key in ["Resume","Sound","Music","Title"]:
		var button: Button = canvas.get_node(key)
		button.add_theme_font_size_override("font_size",18)
		for state in ["normal","hover","pressed"]:
			var style := StyleBoxFlat.new()
			style.bg_color = Color("315c4a") if state == "hover" else Color("193b31")
			style.border_color = Color("ad9764")
			style.set_border_width_all(1)
			style.set_corner_radius_all(6)
			button.add_theme_stylebox_override(state,style)

# Mode-owned state is supplied explicitly; reusable components never inspect the game.
func present(view: Dictionary, mode: Dictionary) -> void:
	var boss: Dictionary = mode.get("boss",{})
	$Root/Boss.visible = not boss.is_empty()
	$Root/BossHP.visible = not boss.is_empty()
	if $Root/Decor.boss_visible != $Root/BossHP.visible:
		$Root/Decor.boss_visible = $Root/BossHP.visible
		$Root/Decor.queue_redraw()
	if not boss.is_empty(): $Root/BossHP.refresh(boss.hp,boss.max_hp,0)
	if not boss.is_empty(): $Root/Boss.text = "独楽の鋳造機"+("  暴走" if boss.second else "")
	$Root/Map.visible = true
	$Root/Map.disabled = not mode.get("map_available",false) or mode.paused or not mode.result.is_empty()
	$Root/Help.size.x = 730
	View.refresh_health($Root/HP,$Root/Health,view)
	$Root/HP.tooltip_text = $Root/Health.text
	$Root/Active.refresh(view)
	for slot in slots: slot.refresh(view)
	View.refresh_actions(actions,view)
	$Root/Heading.visible = false
	$Root/Help.text = mode.door_hint if not mode.paused and mode.result.is_empty() and not mode.encounter_active else ""
	$Root/Status.text = "敵なし  ·  移動・射撃・UIを自由に確認できます"
	if mode.get("encounter_cleared",false): $Root/Status.text = "攻略済み  ·  次の部屋へ進めます"
	if mode.get("room_role","") == "treasure":
		$Root/Status.text = "宝箱を発見  ·  近づいてFで開封" if mode.get("reward_state","") == "closed" else "箱の中身を回収できます" if mode.get("reward_state","") == "open" else "宝箱回収済み  ·  次の部屋へ進めます"
	var gold: int = mode.get("gold",0)
	$Root/Gold.text = str(gold)
	# A gain briefly enlarges and brightens the counter; spending does not.
	if shown_gold >= 0 and gold > shown_gold:
		var label: Label = $Root/Gold
		label.pivot_offset = Vector2(0,11)
		var tween := label.create_tween()
		label.scale = Vector2.ONE*1.3
		label.modulate = Color(1.6,1.5,1.1)
		tween.tween_property(label,"scale",Vector2.ONE,.25)
		tween.parallel().tween_property(label,"modulate",Color.WHITE,.25)
	shown_gold = gold
	match mode.get("room_role",""):
		"shop": $Root/Status.text = "工房の露店  ·  品物に近づいてFで効果・価格を確認"
		"altar": $Root/Status.text = "祭壇の間  ·  HPを1捧げるとレリックを授かる"
		"challenge": $Root/Status.text = "試練の間  ·  中央の台で挑戦するか選べます" if not mode.get("encounter_cleared",false) else "試練を突破"
	if mode.get("room_role","") == "antechamber": $Root/Status.text = "ボス前室  ·  Tabで装備整理  ·  北の扉は独楽の鋳造機へ"
	if mode.get("room_role","") == "boss": $Root/Status.text = "独楽の鋳造機  ·  動作を見て攻撃を避けよう"
	if mode.get("room_role","") == "boss" and mode.get("encounter_cleared",false): $Root/Status.text = ""
	if mode.encounter_active: $Root/Status.text = "敵を倒す  ·  残り%d体" % mode.enemies_alive
	if not boss.is_empty() and boss.intro: $Root/Status.text = ""
	if mode.paused: $Root/Status.text = "停止中  ·  Escで再開"
	if not mode.result.is_empty(): $Root/Status.text = "今回の挑戦は終了しました"
	$Root/Pause.text = ""
	$Root/Bag.disabled = mode.paused or not mode.result.is_empty()
	if mode.get("bag_open",false): $Root/Status.text = ""
	if mode.get("map_open",false): $Root/Status.text = "マップ表示中  ·  M・Escで閉じる"
	$Root/Pause.disabled = not mode.result.is_empty()
	$Root/Sound.text = "SE ON" if mode.sound_enabled else "SE OFF"
	$Root/Outcome.visible = not mode.result.is_empty() and mode.get("result_visible",true)
	$Root/Outcome/Message.text = mode.result

	# 2026-10-05: A layout; only real item slots occupy the lower edge.
	var count: int = mini(MAX_WEAPON_SLOTS,view.weapons.size())
	var width: float = count*44+maxi(0,count-1)*3
	$Root/Loadout.size = Vector2(width,48)
	$Root/Loadout.position = Vector2(786-width,726)
	var menu_open: bool = mode.get("pause_menu",mode.paused) and mode.result.is_empty() and not mode.get("bag_open",false) and not mode.get("map_open",false) and not mode.get("shop_open",false)
	$Root/PauseMenu.visible = menu_open
	if $Root/Decor.pause_menu != menu_open:
		$Root/Decor.pause_menu = menu_open
		$Root/Decor.queue_redraw()
	for key in ["Resume","Sound","Music"]: get_node("Root/"+key).visible = menu_open
	$Root/Title.visible = menu_open or not mode.result.is_empty()
	$Root/Title.position.y = 430 if menu_open else 454
	var music = get_node_or_null("/root/Music")
	if music != null:
		music.toggle.hide()
		$Root/Music.text = "BGM ON" if music.enabled else "BGM OFF"
	if shown_hp>=0 and view.hp<shown_hp:
		$Root/HP.modulate = Color(1.6,1.1,1.1)
		var flash := create_tween()
		flash.tween_property($Root/HP,"modulate",Color.WHITE,.22)
	shown_hp = view.hp
	if shown_weapon != view.selected:
		shown_weapon = view.selected
		$Root/Active/Art.modulate = Color(1.4,1.4,1.2)
		var flash := create_tween()
		flash.tween_property($Root/Active/Art,"modulate",Color.WHITE,.18)
