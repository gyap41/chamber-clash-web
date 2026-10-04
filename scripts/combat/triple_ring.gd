extends "res://scripts/combat/ring_sentry.gd"
func _init() -> void:
	spec = Spec.RING.duplicate(true)
	spec.merge({"id":"triple_ring","machine_audio":true,"windup_sound":"machine_ring_windup","attack_sound":"machine_ring_salvo","name":"三連環砲機","hp":7.0,"shots":3,"shot_interval":0.5,"recovery":2.4},true)
func enemy_visual_snapshot() -> Dictionary:
	var view := super.enemy_visual_snapshot()
	view.enemy_id = spec.id
	view.firing_muzzles = firing_muzzles.duplicate()
	view.shot_interval = float(spec.get("shot_interval",.5))
	return view
func _draw() -> void:
	preload("res://scripts/visuals/elite_machine_visual.gd").paint(self,enemy_visual_snapshot())
