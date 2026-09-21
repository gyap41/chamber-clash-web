extends Node2D
## Two independent, editor-authored graphs: locomotion and weapon actions.
## BodyPlayer owns actual body/foot keyframes; the weapon graph is independent.
const Snapshot = preload("res://scripts/visuals/actor_visual_state.gd")
@export var body_state: StringName = &"idle"
@export var weapon_state: StringName = &"disabled"
@onready var body_tree: AnimationTree = $BodyTree
@onready var weapon_tree: AnimationTree = $WeaponTree
@onready var body_playback: AnimationNodeStateMachinePlayback = body_tree.get("parameters/playback")
@onready var weapon_playback: AnimationNodeStateMachinePlayback = weapon_tree.get("parameters/playback")
@onready var parts = $Parts

func _ready() -> void:
	reset()

func reset() -> void:
	body_playback.start(&"idle")
	weapon_playback.start(&"disabled")
	body_tree.advance(0)
	weapon_tree.advance(0)
	body_state = body_playback.get_current_node()
	parts.reset_motion()

func restart_fire() -> void:
	# Repeated shots are events even when the weapon stays in the fire state.
	if weapon_state == &"fire":
		weapon_playback.start(&"fire")
		weapon_tree.advance(0)

func present(snapshot: Snapshot, firing: bool, dt: float = 0.0) -> void:
	# travel uses the authored transitions; repeating the same state must not
	# restart a clip. Refreshes after fire/equip use dt=0, so time advances once.
	var body_target := snapshot.body_target()
	var weapon_target := snapshot.weapon_target(firing)
	if body_playback.get_current_node() != body_target:
		if body_target in [&"roll",&"dead"]:
			# Gameplay interrupts cannot wait for a locomotion crossfade.
			body_playback.start(body_target)
		else:
			body_playback.travel(body_target)
		# Godot resolves travel after sampling the outgoing clip. Settle the
		# transition at zero time before sampling the destination in this tick.
		body_tree.advance(0)
		if body_playback.get_current_node() != body_target:
			# Reverse a just-started walk/stop blend on fresh input immediately.
			body_playback.next()
			body_tree.advance(0)
	if weapon_playback.get_current_node() != weapon_target:
		weapon_playback.travel(weapon_target)
		weapon_tree.advance(0)
	var tempo := clampf(snapshot.move_speed/205.0,.4,2.0) if body_target == &"move" else 1.0
	body_tree.advance(dt*tempo)
	weapon_tree.advance(dt)
	# Logical state is immediate even while numeric pose tracks crossfade.
	body_state = body_playback.get_current_node()
