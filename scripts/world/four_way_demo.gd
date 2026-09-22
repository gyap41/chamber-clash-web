extends RefCounted
# Opt-in integration fixture. Produces ordinary room resources, not another builder.
const Room = preload("res://scripts/world/room_template.gd")
const Field = preload("res://scripts/world/field_definition.gd")
const ART_THEME = preload("res://data/stage_themes/workshop_showcase.tres")
const DIRECTIONS := {"north":Vector2.UP,"south":Vector2.DOWN,"west":Vector2.LEFT,"east":Vector2.RIGHT}
const OPPOSITE := {"north":"south","south":"north","west":"east","east":"west"}
const NAMES := {"north":"北の作業室","south":"南の作業室","west":"西の作業室","east":"東の作業室"}
static func catalog() -> Dictionary:
	var result := {"crossroads":make_room("crossroads",["north","south","west","east"])}
	result.crossroads.display_name = "四方向の接続確認室"
	for side in DIRECTIONS:
		result[side] = make_room(side,[OPPOSITE[side]])
		result[side].display_name = NAMES[side]
		result[side].doors[0].target_room = "crossroads"
		result[side].doors[0].target_door = side
	return result
static func make_room(id: String, sides: Array):
	return preload("res://scripts/world/workshop_room_shell.gd").make_room(id,sides)
