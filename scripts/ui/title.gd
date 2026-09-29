extends Control
# CPU matches and the exploration prototype own separate scene/state lifecycles.
@export var character_select_scene: PackedScene = preload("res://scenes/ui/character_select.tscn")
func _ready() -> void:
	get_node("/root/Music").play_context("title")
	$Panel/Content/Version.text = "v%s" % ProjectSettings.get_setting("application/config/version", "dev")
	$Panel/Content/Start.pressed.connect(start_cpu_match)
	$Panel/Content/Story.pressed.connect(start_story)
	$Panel/Content/RandomFloor.pressed.connect(start_random_floor)
	$Panel/Content/CombatLab.pressed.connect(start_combat_lab)
func start_combat_lab() -> void:
	var lab = load("res://scenes/game/combat_lab.tscn").instantiate()
	get_tree().root.add_child(lab)
	get_parent().remove_child(self)
	queue_free()
func start_random_floor() -> void:
	var exploration = load("res://scenes/game/exploration.tscn").instantiate()
	exploration.random_floor = true
	exploration.authored_campaign = true
	get_tree().root.add_child(exploration)
	get_parent().remove_child(self)
	queue_free()
func start_story() -> void:
	var exploration = load("res://scenes/game/exploration.tscn").instantiate()
	get_tree().root.add_child(exploration)
	get_parent().remove_child(self)
	queue_free()
func start_cpu_match() -> void:
	var select = character_select_scene.instantiate()
	select.cpu_mode = true
	get_tree().root.add_child(select)
	get_parent().remove_child(self)
	queue_free()
