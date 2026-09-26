extends RefCounted
# Logical play area excludes the fixed HUD bands (90px top, 110px bottom).
const ZOOM := 1.2
# 試験：キャラの大きさ案D（2026-09-26）。参考動画との比較で、カメラを寄せてキャラを大きく見せる。
# 既定は無効。ゲーム中の C キー、または起動引数 --size-d で切替。遊び方への影響を確かめるための一時設定。
const ZOOM_D := 1.45
static var size_d := OS.get_cmdline_user_args().has("--size-d")
static func zoom() -> float:
	return ZOOM_D if size_d else ZOOM
const CHAR_SCALE_D := 1.1 # 案Dでのリナ（仮組み込みの描画）の表示倍率。当たり判定は変えない
static var last_toggle_event := 0
static func toggle_size_d(event: InputEvent = null) -> void:
	if event != null:
		if last_toggle_event == event.get_instance_id(): return
		last_toggle_event = event.get_instance_id()
	size_d = not size_d
const PLAY_SIZE := Vector2(1120,600)
const PLAY_OFFSET := Vector2(0,90)
static func axis_origin(start: float, length: float, view: float, target: float) -> float:
	if length <= view: return start+(length-view)*.5
	return clampf(target-view*.5,start,start+length-view)
static func origin(bounds: Rect2, target: Vector2) -> Vector2:
	return Vector2(axis_origin(bounds.position.x,bounds.size.x,PLAY_SIZE.x/zoom(),target.x),
		axis_origin(bounds.position.y,bounds.size.y,PLAY_SIZE.y/zoom(),target.y))-PLAY_OFFSET/zoom()
static func follow(camera: Camera2D, bounds: Rect2, target: Vector2, snap: bool = false) -> void:
	camera.anchor_mode = Camera2D.ANCHOR_MODE_FIXED_TOP_LEFT
	camera.zoom = Vector2.ONE*zoom()
	# Direct following avoids lag during dodge and overshoot at room boundaries.
	camera.position_smoothing_enabled = false
	camera.position = origin(bounds,target)
	if snap:
		camera.offset = Vector2.ZERO
		camera.reset_smoothing()
	camera.force_update_scroll()

static func visible_rect(bounds: Rect2, target: Vector2) -> Rect2:
	return Rect2(origin(bounds,target)+PLAY_OFFSET/zoom(),PLAY_SIZE/zoom())
