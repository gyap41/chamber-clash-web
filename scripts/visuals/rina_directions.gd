extends RefCounted
const Dodge = preload("res://scripts/visuals/rina_dodge.gd")
const RECT = Rect2(-32,-45,64,64)
static var textures: Dictionary = {}

static func shoe_offset(phase: float, foot: int, direction: Vector2) -> Vector2:
	var angle := phase*TAU/6.0+foot*PI
	# One shoe supports the body while the opposite shoe returns toward the hem.
	# Keep the support shoe on the standing plane for all movement directions.
	return Vector2(direction.x*cos(angle)*1.6,-maxf(0,sin(angle))*1.25)

static func body_pose(phase: float, walking: bool, elapsed: float) -> Transform2D:
	var weight := sin(phase*TAU/6.0) if walking else 0.0
	var compression := .012*(1-absf(weight)) if walking else .004*(1+sin(elapsed*2.0))
	# Squash and weight transfer pivot at the soles; never lift the torso off its feet.
	return Transform2D(0,Vector2(0,15))*Transform2D(weight*.012,Vector2(1,1-compression),0,Vector2.ZERO)*Transform2D(0,Vector2(0,-15))

static func texture(view: String, part: String = "") -> Texture2D:
	var row := "side" if view in ["left","right"] else view
	var key := row+part
	if not textures.has(key):
		textures[key] = load("res://assets/first-workshop/rina-directions/"+key+".png")
	return textures[key]

static func render(canvas: Node2D, base: Transform2D, view: String, walking: bool,
		phase: float, direction: Vector2, roll_progress: float, elapsed: float, color: Color) -> void:
	if roll_progress >= 0:
		Dodge.render(canvas,base,view,roll_progress,color)
		return
	canvas.draw_set_transform_matrix(base)
	# In profile the far shoe is behind the near shoe; neither changes its drawn shape.
	for foot in [1,0]:
		var offset := shoe_offset(phase,foot,direction) if walking else Vector2.ZERO
		canvas.draw_texture_rect(texture(view,"-foot-"+str(foot)),Rect2(RECT.position+offset,RECT.size),false,color)
	canvas.draw_set_transform_matrix(base*(body_pose(phase,walking,elapsed) if roll_progress < 0 else Transform2D.IDENTITY))
	canvas.draw_texture_rect(texture(view,"-body"),RECT,false,color)
