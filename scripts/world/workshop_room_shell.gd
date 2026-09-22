extends RefCounted
# Shared rectangular workshop shell with authored cardinal opening dimensions.
const Room = preload("res://scripts/world/room_template.gd")
const Field = preload("res://scripts/world/field_definition.gd")
const ART_THEME = preload("res://data/stage_themes/workshop_showcase.tres")
const DIRECTIONS := {"north":Vector2.UP,"south":Vector2.DOWN,"west":Vector2.LEFT,"east":Vector2.RIGHT}
const OPPOSITE := {"north":"south","south":"north","west":"east","east":"west"}
const NAMES := {"north":"北の作業室","south":"南の作業室","west":"西の作業室","east":"東の作業室"}
static func wall(field, id: String, rect: Rect2, role: String) -> void:
	if not rect.has_area(): return
	field.walls.append(rect)
	field.wall_ids.append(id)
	field.wall_materials[id] = role
static func make_room(id: String, sides: Array, dimensions: Vector2 = Vector2(1120,600)):
	var room := Room.new()
	var field := Field.new()
	room.field = field
	room.display_name = id
	field.field_id = id
	field.theme = ART_THEME
	field.constrain_to_floor = true
	field.field_rect = Rect2(Vector2.ZERO,dimensions)
	field.fighter_bounds = Rect2(60,82,dimensions.x-120,dimensions.y-142)
	field.projectile_bounds = Rect2(32,37,dimensions.x-64,dimensions.y-67)
	var right := dimensions.x-128
	var bottom := dimensions.y-88
	field.floor_regions = [Rect2(128,128,right-128,bottom-128)]
	field.spawns = PackedVector2Array([dimensions*.5])
	for side in DIRECTIONS:
		var vertical: bool = side in ["north","south"]
		var width := 144.0 if vertical else 112.0
		var center := dimensions.x*.5 if vertical else dimensions.y*.5
		var start := center-width*.5
		var finish := center+width*.5
		var has_door: bool = side in sides
		if vertical:
			var y := 80.0 if side == "north" else bottom
			var height := 48.0 if side == "north" else 32.0
			var role := "face" if side == "north" else "top"
			if has_door:
				wall(field,side+"_a",Rect2(96,y,start-96,height),role)
				wall(field,side+"_b",Rect2(finish,y,right+32-finish,height),role)
				field.floor_regions.append(Rect2(start,y,width,height))
			else: wall(field,side,Rect2(96,y,right-64,height),role)
		else:
			var x := 96.0 if side == "west" else right
			if has_door:
				wall(field,side+"_a",Rect2(x,128,32,start-128),"top")
				wall(field,side+"_b",Rect2(x,finish,32,bottom-finish),"top")
				var passage_x := 16.0 if side == "west" else right+32
				wall(field,side+"_passage_a",Rect2(passage_x,start-32,80,32),"face")
				wall(field,side+"_passage_b",Rect2(passage_x,finish,80,32),"top")
				field.floor_regions.append(Rect2(16 if side == "west" else right,start,112,width))
			else: wall(field,side,Rect2(x,128,32,bottom-128),"top")
		if has_door:
			var point: Vector2
			match side:
				"north": point = Vector2(dimensions.x*.5,104)
				"south": point = Vector2(dimensions.x*.5,dimensions.y-70)
				"west": point = Vector2(70,dimensions.y*.5)
				"east": point = Vector2(dimensions.x-70,dimensions.y*.5)
			room.doors.append({"id":side,"position":point,"direction":DIRECTIONS[side],"width":width,
				"arrival":point-DIRECTIONS[side]*100,"target_room":side,"target_door":OPPOSITE[side]})
	return room
