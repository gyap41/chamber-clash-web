extends Control
const Characters = preload("res://scripts/catalog/character_catalog.gd")
@export var main_scene: PackedScene = preload("res://scenes/game/main.tscn")
var char_turn := 0
var picked: Array = [-1, -1]
# CPU対戦: only P1 picks a character; P2 is a random pick (excluding P1's) applied as
# player[1].is_cpu, matching legacy's mode==='cpu' selectCharacter() branch.
var cpu_mode := false
func _ready() -> void:
	$Panel/Content/ModeRow/Local.pressed.connect(func(): set_mode(false))
	$Panel/Content/ModeRow/Cpu.pressed.connect(func(): set_mode(true))
	refresh()
func set_mode(cpu: bool) -> void:
	if char_turn != 0: return # a pick is already in progress; ignore mode changes mid-select
	cpu_mode = cpu
	refresh()
func select_character(id: int) -> void:
	if char_turn < 0 or char_turn > 1: return
	picked[char_turn] = id
	if cpu_mode and char_turn == 0:
		var pool: Array = []
		for n in range(Characters.count()):
			if n != id: pool.append(n)
		picked[1] = pool.pick_random()
		start_match()
		return
	char_turn += 1
	if char_turn >= 2:
		start_match()
	else:
		refresh()
func refresh() -> void:
	$Panel/Content/ModeRow/Local.button_pressed = not cpu_mode
	$Panel/Content/ModeRow/Cpu.button_pressed = cpu_mode
	$Panel/Content/ModeRow/Local.disabled = char_turn != 0
	$Panel/Content/ModeRow/Cpu.disabled = char_turn != 0
	$Panel/Content/Title.text = "P1：キャラクターを選択" if cpu_mode else "P%d：キャラクターを選択" % (char_turn+1)
	$Panel/Content/Info.text = "HP・移動速度・装填時間・回避クールダウン・パルス回数がキャラごとに異なります。" + ("CPU（P2）はP1と異なるキャラからランダムに選ばれます。" if cpu_mode else "両者とも重複選択可。")
	for child in $Panel/Content/Cards.get_children():
		child.get_parent().remove_child(child)
		child.queue_free()
	for id in range(Characters.count()):
		var c: Dictionary = Characters.definition(id)
		var button := Button.new()
		# Fixed at 245x150 so 4 columns (245*4 + 3*8px separation = 1004px) stay within the
		# Panel's ~1040px content width. clip_text + ellipsis keep long note text from
		# widening the button past custom_minimum_size, which is what pushed cards off the
		# 1120px-wide screen before: an un-clipped Button's minimum size grows to fit the
		# full text on one line, and that ballooned width multiplies across the row.
		button.custom_minimum_size = Vector2(245,150)
		button.focus_mode = Control.FOCUS_NONE
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.clip_text = true
		button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		button.icon = Characters.art(id)
		button.icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		button.expand_icon = true
		button.add_theme_constant_override("icon_max_width",90)
		button.text = "%s（%s）\nHP%d・速度%d" % [c.name, c.role, c.hp, c.speed]
		button.tooltip_text = c.note
		button.pressed.connect(select_character.bind(id))
		$Panel/Content/Cards.add_child(button)
# Both picks are done: hand off to the real match scene. main.tscn's own _ready() (called
# synchronously by add_child, same as every headless test relies on) runs reset_round() with
# the shared Inspector-default stats first; set_character() is applied right after and patches
# the already-built state dict in place, so main.gd's fighters[] reference stays valid.
func start_match() -> void:
	var game = main_scene.instantiate()
	get_tree().root.add_child(game)
	for i in range(2):
		game.players[i].set_character(picked[i])
	game.players[1].is_cpu = cpu_mode
	get_parent().remove_child(self)
	queue_free()
