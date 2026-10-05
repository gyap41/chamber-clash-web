extends "res://scripts/combat/exploration_enemy.gd"
func _init() -> void:
	spec = Spec.RUNNER
func prepare(spawn: Vector2) -> void:
	attack_phase = "grace"
	super.prepare(spawn)
func _draw() -> void:
	if preload("res://scripts/visuals/remaining_machine_visual.gd").paint(self,enemy_visual_snapshot()): return
	preload("res://scripts/visuals/sentry_variants_visual.gd").paint(self,enemy_visual_snapshot())
