extends Node2D
## Authored AnimationPlayer tracks move the body and feet. This adapter only
## binds directional textures and adds movement-dependent lean / grip follow.
const Rig = preload("res://scripts/visuals/character_rig.gd")
var character_id := -2
var view := ""
var lean := 0.0
var lean_velocity := 0.0
@onready var body: Sprite2D = $Lean/Body/Sprite
@onready var foot0: Sprite2D = $Foot0/Sprite
@onready var foot1: Sprite2D = $Foot1/Sprite

func reset_motion() -> void:
	lean = 0.0
	lean_velocity = 0.0
	$Lean.rotation = 0.0
	visible = false

func present(id: int, facing_view: String, base: Transform2D, direction: Vector2,
		color: Color, motion: StringName, speed_ratio: float, dt: float) -> void:
	visible = id >= 0 and motion != &"roll"
	if id < 0: return
	if id != character_id or facing_view != view:
		character_id = id
		view = facing_view
		var row := "side" if view in ["left","right"] else view
		body.texture = Rig.texture(id,row+"-body")
		foot0.texture = Rig.texture(id,row+"-foot-0")
		foot1.texture = Rig.texture(id,row+"-foot-1")
	transform = base
	modulate = color
	# A critically damped response keeps the start/stop lean stable at any fps.
	var target := direction.x*.09*clampf(speed_ratio,.65,1.4) if motion == &"move" else 0.0
	if motion in [&"roll",&"dead"]:
		lean = 0.0
		lean_velocity = 0.0
	elif dt > 0:
		var omega := 18.0
		var displacement := lean-target
		var velocity_term := lean_velocity+omega*displacement
		var decay := exp(-omega*dt)
		lean = target+(displacement+velocity_term*dt)*decay
		lean_velocity = (lean_velocity-omega*velocity_term*dt)*decay
	$Lean.rotation = lean
	# The canonical clip strides to the right. Correct translation, not image
	# scale, for strafing/backpedaling; vertical motion retains planted support.
	var support := maxf($Foot0.position.y,$Foot1.position.y)
	foot0.position = Vector2($Foot0.position.x*(direction.x-1),-13-support)
	foot1.position = Vector2($Foot1.position.x*(direction.x-1),-13-support)

func grip_offset() -> Vector2:
	if not visible: return Vector2.ZERO
	var grip: Vector2 = $Lean.transform*$Lean/Body.transform*Vector2(0,-7)
	return (transform.basis_xform(grip-Vector2(0,8))).limit_length(2.0)
