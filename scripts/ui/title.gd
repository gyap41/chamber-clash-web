extends Control
# Entry point (project.godot's run/main_scene). Local 2-player is being deprioritized in
# favor of a future online mode (per 2026-09-08 planning), so this screen offers only a single
# "start" action that goes straight into a CPU match — it does not show a Local/CPU choice.
# scenes/character_select.tscn's own Local/Cpu ModeRow toggle is left in place in the scene and
# script (untouched) for that future work; this screen simply presets character_select's
# cpu_mode to true before handing off, the same way character_select.gd's own start_match()
# hands off to main.tscn.
@export var character_select_scene: PackedScene = preload("res://scenes/ui/character_select.tscn")
func _ready() -> void:
	$Panel/Content/Start.pressed.connect(start_cpu_match)
func start_cpu_match() -> void:
	var select = character_select_scene.instantiate()
	select.cpu_mode = true
	get_tree().root.add_child(select)
	get_parent().remove_child(self)
	queue_free()
