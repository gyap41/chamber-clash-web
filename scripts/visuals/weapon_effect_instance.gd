extends Node2D
# Optional custom scene contract. Subclasses may draw/animate, never mutate combat.
# The presentation owner advances time; do not use independent process/timer callbacks.
var event: Dictionary = {}
var spec: Dictionary = {}
var age := 0.0
func configure(value: Dictionary, definition: Dictionary) -> void:
	event = value.duplicate(true)
	spec = definition.duplicate(true)
	position = event.get("pos",Vector2.ZERO)
	rotation = float(event.get("angle",0.0))
	age = 0.0
func advance(dt: float) -> bool:
	age += dt
	var actor = event.anchor.get_ref() if event.get("anchor") is WeakRef else null
	if actor != null: position = actor.position
	queue_redraw()
	return age < float(spec.get("duration",.2))
