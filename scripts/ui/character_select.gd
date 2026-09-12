extends Control
const Characters = preload("res://scripts/catalog/character_catalog.gd")
@export var main_scene: PackedScene = preload("res://scenes/game/main.tscn")
var char_turn := 0
var picked: Array = [-1, -1]
# CPU対戦: only P1 picks a character; P2 is a random pick (excluding P1's) applied as
# player[1].is_cpu, matching legacy's mode==='cpu' selectCharacter() branch.
var cpu_mode := true
func _ready() -> void:
	$Panel/Content/ModeRow.hide()
	refresh()
func set_mode(_cpu: bool) -> void:
	cpu_mode = true
	refresh()
func select_character(id: int) -> void:
	if id not in Characters.ids(): return
	picked[0] = id
	var pool: Array = Characters.ids().filter(func(candidate): return candidate != id)
	picked[1] = pool.pick_random()
	start_match()
func refresh() -> void:
	$Panel/Content/Title.text = "キャラクターを選択"
	$Panel/Content/Info.text = "HP・移動速度・装填時間・回避クールダウン・パルス回数がキャラごとに異なります。CPUは異なるキャラからランダムに選ばれます。"
	for child in $Panel/Content/Cards.get_children():
		child.get_parent().remove_child(child)
		child.queue_free()
	for id in Characters.ids():
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
	# P8z：キャラクターごとの初期武器（data/catalog.jsonのcharacters[].gun）を所持庫へ入れる
	# 必要があるため、set_character()を直接呼ばずmain.gd側の入口を通す。
	for i in range(2):
		game.assign_character(i,picked[i])
	game.players[1].is_cpu = true
	# _ready() drew the placeholder P-12 before either character was assigned.
	# Rebuild once with both final builds and CPU mode, clearing stale selections.
	game.preparation.begin()
	get_parent().remove_child(self)
	queue_free()
