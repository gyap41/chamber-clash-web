extends RefCounted
# Prototype parts rendered from combat time. No independent animation clock or floor tell.
static func pose(view: Dictionary) -> Dictionary:
	var direction := Vector2.from_angle(float(view.angle))
	var body := Vector2.ZERO
	var tool_angle := float(view.angle)+.65
	var reach := 25.0
	var raised := 0.0
	if view.phase == "windup":
		var progress := clampf(1.0-float(view.remaining)/float(view.windup),0,1)
		# Pull back and hold visibly; the final tenth of a second swings toward the hit.
		var lift := smoothstep(0.0,.35,progress)
		var swing := smoothstep(.84,1.0,progress)
		tool_angle = float(view.angle)+lerpf(-1.6*lift,0.0,swing)
		raised = 16.0*lift*(1.0-swing)
		reach = lerpf(25.0,float(view.reach)-8.0,swing)
		body = -direction*5.0*lift*(1.0-swing)
	elif view.phase == "recover":
		var elapsed := float(view.recovery)-float(view.remaining)
		var settle := smoothstep(.15,float(view.recovery),elapsed)
		tool_angle = float(view.angle)+.65*settle
		reach = lerpf(float(view.reach)-8.0,25.0,settle)
		body = direction*3.0*(1.0-settle)
	return {"body":body,"tool_angle":tool_angle,"reach":reach,"raised":raised}

static func paint(canvas: Node2D, view: Dictionary) -> void:
	preload("res://scripts/visuals/enemy_sheet_visual.gd").paint(canvas,view,false)
