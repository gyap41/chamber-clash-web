extends RefCounted
# Dedicated drawn poses. Gameplay duration/invulnerability stay in Player.
const RECT = Rect2(-64,-65,128,96)
static var textures: Dictionary = {}

static func stage(progress: float) -> int:
	var time := clampf(progress,0,1)*.38
	return 0 if time < .04 else (1 if time < .26 else 2)

static func texture(view: String, pose: int) -> Texture2D:
	var row := "side" if view in ["left","right"] else view
	var key := row+"-"+str(pose)
	if not textures.has(key):
		textures[key] = load("res://assets/first-workshop/rina-dodge/"+key+".png")
	return textures[key]

static func lift(progress: float) -> float:
	var time := clampf(progress,0,1)*.38
	if time < .04 or time >= .26: return 0.0
	return sin((time-.04)/.22*PI)*6.0

static func render(canvas: Node2D, base: Transform2D, view: String, progress: float, color: Color) -> void:
	canvas.draw_set_transform_matrix(base*Transform2D(0,Vector2(0,-lift(progress))))
	canvas.draw_texture_rect(texture(view,stage(progress)),RECT,false,color)
