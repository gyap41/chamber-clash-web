extends RefCounted
const Gait=preload("res://scripts/visuals/rina_directions.gd")
const NAMES=["00-rina","01-sora","02-kohaku","03-bolt","04-mei","05-luna","06-rattle","07-crow"]
const RECT=Rect2(-32,-45,64,64)
const DODGE_RECT=Rect2(-64,-65,128,96)
static var cache: Dictionary={}

static func texture(id: int, part: String) -> Texture2D:
	var key=str(id)+part
	if not cache.has(key):
		cache[key]=load("res://assets/first-workshop/directional-characters/"+NAMES[id]+"/"+part+".png")
	return cache[key]

static func dodge_stage(progress: float) -> int:
	return 0 if progress<.15 else (1 if progress<.72 else 2)

static func render(canvas: Node2D, id: int, base: Transform2D, view: String,
		walking: bool, phase: float, direction: Vector2, progress: float, elapsed: float, color: Color) -> void:
	var row="side" if view in ["left","right"] else view
	if progress>=0:
		var lift=0.0
		if progress>=.15 and progress<.72:
			lift=sin((progress-.15)/.57*PI)*[0.0,3.0,6.0,1.0,2.0,7.0,3.0,3.0][id]
		canvas.draw_set_transform_matrix(base*Transform2D(0,Vector2(0,-lift)))
		canvas.draw_texture_rect(texture(id,row+"-dodge-"+str(dodge_stage(progress))),DODGE_RECT,false,color)
		return
	canvas.draw_set_transform_matrix(base)
	for foot in [1,0]:
		var offset=Gait.shoe_offset(phase,foot,direction) if walking else Vector2.ZERO
		canvas.draw_texture_rect(texture(id,row+"-foot-"+str(foot)),Rect2(RECT.position+offset,RECT.size),false,color)
	canvas.draw_set_transform_matrix(base*Gait.body_pose(phase,walking,elapsed))
	canvas.draw_texture_rect(texture(id,row+"-body"),RECT,false,color)
