extends RefCounted
# Fixed texture parts: every frame reuses the same silhouette and UV coordinates.
const RinaDirections = preload("res://scripts/visuals/rina_directions.gd")
const Directions = preload("res://scripts/visuals/character_directions.gd")

static func texture(id: int, part: String) -> Texture2D:
	if id == 0:
		var separator := part.find("-")
		return RinaDirections.texture(part if separator < 0 else part.left(separator),"" if separator < 0 else part.substr(separator))
	return Directions.texture(id,part)

static func render(canvas: Node2D, id: int, base: Transform2D, _back: bool,
		walking: bool, phase: float, direction: Vector2, roll_progress: float,
		elapsed: float, color: Color, view: String = "front") -> void:
	if id == 0:
		RinaDirections.render(canvas,base,view,walking,phase,direction,roll_progress,elapsed,color)
		return
	Directions.render(canvas,id,base,view,walking,phase,direction,roll_progress,elapsed,color)
