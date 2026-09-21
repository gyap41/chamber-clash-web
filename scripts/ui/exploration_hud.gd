extends CanvasLayer
const Widgets = preload("res://scripts/ui/hud_widgets.gd")
const View = preload("res://scripts/ui/combat_hud_view.gd")
const HealthBar = preload("res://scripts/ui/hp_bar.gd")
const WeaponPanel = preload("res://scripts/ui/hud_weapon_panel.gd")
const WeaponSlot = preload("res://scripts/ui/hud_weapon_slot.gd")
const Action = preload("res://scripts/ui/hud_action.gd")
const MAX_WEAPON_SLOTS := 8
signal slot_requested(index: int)
signal pause_requested
signal retry_requested
signal title_requested
signal sound_requested
var slots: Array = []
var actions: Array = []
func _ready() -> void:
	var canvas := Control.new()
	canvas.name = "Root"
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(canvas)
	Widgets.box(canvas,"Header",Rect2(12,6,1096,80))
	Widgets.label(canvas,"Name",Rect2(28,10,280,25),20).text = "リナ"
	var health := HealthBar.new()
	health.name = "HP"
	health.position = Vector2(28,40)
	health.size = Vector2(280,16)
	health.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(health)
	Widgets.label(canvas,"Health",Rect2(28,58,300,22),17)
	Widgets.label(canvas,"Heading",Rect2(350,12,440,26),20)
	Widgets.label(canvas,"Status",Rect2(350,47,470,24),15)
	Widgets.button(canvas,"Pause",Rect2(830,22,128,42),"Esc 停止",func(): pause_requested.emit())
	Widgets.button(canvas,"Title",Rect2(972,22,120,42),"タイトルへ",func(): title_requested.emit())
	Widgets.box(canvas,"Dock",Rect2(12,700,1096,92))
	var active := WeaponPanel.new()
	active.name = "Active"
	active.position = Vector2(26,706)
	canvas.add_child(active)
	var loadout := HBoxContainer.new()
	loadout.name = "Loadout"
	loadout.position = Vector2(244,717)
	loadout.size = Vector2(380,56)
	loadout.add_theme_constant_override("separation",3)
	canvas.add_child(loadout)
	for i in range(MAX_WEAPON_SLOTS):
		var slot := WeaponSlot.new()
		slot.slot_index = i
		slot.slot_requested.connect(func(index): slot_requested.emit(index))
		loadout.add_child(slot)
		slots.append(slot)
	for i in range(3):
		var action := Action.new()
		action.position = Vector2(640+i*76,710)
		action.size = Vector2(72,72)
		canvas.add_child(action)
		action.configure(["dodge","melee","pulse"][i],["SPACE","右クリック","Q"][i],["回避","近接","パルス"][i])
		actions.append(action)
	Widgets.button(canvas,"Sound",Rect2(904,710,180,30),"SE ON",func(): sound_requested.emit())
	var help = Widgets.label(canvas,"Help",Rect2(24,667,1072,25),16)
	help.add_theme_color_override("font_shadow_color",Color.BLACK)
	help.add_theme_constant_override("shadow_offset_x",2)
	help.add_theme_constant_override("shadow_offset_y",2)
	var outcome := Widgets.box(canvas,"Outcome",Rect2(310,280,500,150))
	Widgets.label(outcome,"Message",Rect2(16,20,468,36),26).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Widgets.button(outcome,"Retry",Rect2(140,82,220,46),"もう一度挑戦",func(): retry_requested.emit())
	outcome.hide()

# Mode-owned state is supplied explicitly; reusable components never inspect the game.
func present(view: Dictionary, mode: Dictionary) -> void:
	View.refresh_health($Root/HP,$Root/Health,view)
	$Root/Active.refresh(view)
	for slot in slots: slot.refresh(view)
	View.refresh_actions(actions,view)
	$Root/Heading.text = "探索試作 ／ "+mode.room_name
	$Root/Help.text = mode.door_hint if not mode.paused and mode.result.is_empty() else ""
	$Root/Status.text = "敵なし  ·  移動・射撃・UIを自由に確認できます"
	if mode.encounter_active: $Root/Status.text = "敵を倒す  ·  残り%d体" % mode.enemies_alive
	if mode.paused: $Root/Status.text = "停止中  ·  Escで再開"
	if not mode.result.is_empty(): $Root/Status.text = "今回の挑戦は終了しました"
	$Root/Pause.text = "Esc 再開" if mode.paused else "Esc 停止"
	$Root/Pause.disabled = not mode.result.is_empty()
	$Root/Sound.text = "SE ON" if mode.sound_enabled else "SE OFF"
	$Root/Outcome.visible = not mode.result.is_empty()
	$Root/Outcome/Message.text = mode.result
