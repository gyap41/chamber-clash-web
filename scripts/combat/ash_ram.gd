extends "res://scripts/combat/ram_sentry.gd"
func _init() -> void:
	spec = Spec.RAM.duplicate(true)
	spec.merge({"id":"ash_ram","machine_audio":true,"windup_sound":"machine_ram_windup","attack_sound":"machine_ram_launch","name":"灰鎧の破砕機","hp":8.0,"recovery":1.05,"windup":1.25,"damage":1.4},true)
func enemy_visual_snapshot() -> Dictionary:
	var view := super.enemy_visual_snapshot()
	view.enemy_id = spec.id
	view.dash_left = dash_left
	view.shot_interval = float(spec.get("shot_interval",.5))
	return view
func _draw() -> void:
	preload("res://scripts/visuals/elite_machine_visual.gd").paint(self,enemy_visual_snapshot())
