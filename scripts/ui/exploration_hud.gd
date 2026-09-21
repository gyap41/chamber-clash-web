extends CanvasLayer
var heading: Label
var resources: Label
var restart: Button
func _ready() -> void:
	var panel := PanelContainer.new()
	panel.position = Vector2(12,8)
	panel.size = Vector2(1096,76)
	add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",20)
	panel.add_child(row)
	var labels := VBoxContainer.new()
	labels.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(labels)
	heading = Label.new()
	heading.add_theme_font_size_override("font_size",22)
	labels.add_child(heading)
	resources = Label.new()
	labels.add_child(resources)
	restart = Button.new()
	restart.text = "もう一度挑戦"
	restart.focus_mode = Control.FOCUS_NONE
	restart.pressed.connect(func(): get_parent().start_exploration(Time.get_ticks_usec()))
	row.add_child(restart)
	var back := Button.new()
	back.text = "タイトルへ"
	back.focus_mode = Control.FOCUS_NONE
	back.pressed.connect(func(): get_parent().return_to_title())
	row.add_child(back)
	var help := Label.new()
	help.position = Vector2(20,700)
	help.text = "WASD：移動　左クリック：射撃　右クリック：近接　Space：回避　R：装填　Q：パルス　Esc：停止\n探索の基盤テスト：リナで仮の敵を倒す。部屋移動・装備整理・物語は今後追加します。"
	help.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(help)
func refresh(players: Array, _remaining: float, paused: bool, result: String, _scores: Array, _phase: String) -> void:
	heading.text = "ストーリーモード試作 ／ 始まりの工房" if result.is_empty() else result
	if paused: heading.text += "  【停止中・Escで再開】"
	var player = players[0]
	var weapon: Dictionary = player.weapon()
	resources.text = "HP %.1f / %.1f　弾薬 %d / %d　パルス %d　敵HP %.1f" % [player.state.hp,player.state.max_hp,weapon.clip,weapon.reserve,player.state.pulses,players[1].state.hp]
	restart.visible = not result.is_empty()
