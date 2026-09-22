extends RefCounted
# Logical play area excludes the fixed HUD bands (90px top, 110px bottom).
const PLAY_SIZE := Vector2(1120,600)
const PLAY_OFFSET := Vector2(0,90)
static func axis_origin(start: float, length: float, view: float, target: float) -> float:
	if length <= view: return start+(length-view)*.5
	return clampf(target-view*.5,start,start+length-view)
static func origin(bounds: Rect2, target: Vector2) -> Vector2:
	return Vector2(axis_origin(bounds.position.x,bounds.size.x,PLAY_SIZE.x,target.x),
		axis_origin(bounds.position.y,bounds.size.y,PLAY_SIZE.y,target.y))-PLAY_OFFSET
static func follow(camera: Camera2D, bounds: Rect2, target: Vector2, snap: bool = false) -> void:
	camera.anchor_mode = Camera2D.ANCHOR_MODE_FIXED_TOP_LEFT
	camera.zoom = Vector2.ONE
	# Direct following avoids lag during dodge and overshoot at room boundaries.
	camera.position_smoothing_enabled = false
	camera.position = origin(bounds,target)
	if snap:
		camera.offset = Vector2.ZERO
		camera.reset_smoothing()
	camera.force_update_scroll()
