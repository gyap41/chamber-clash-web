extends "res://scripts/combat/weapon_behavior.gd"
func on_event(kind: StringName, context: Dictionary) -> void:
	assert(context.get("session") != null)
	context.actor.set_meta("probe_event",kind)
	if kind == &"launch": context.projectile.state["probe_launch"] = true
