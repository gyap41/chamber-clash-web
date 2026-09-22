extends RefCounted
const Shell = preload("res://scripts/world/workshop_room_shell.gd")
const SPECS := {
	"standard":{"size":Vector2(1120,600),"name":"標準工房"},
	"compact":{"size":Vector2(880,600),"name":"小作業室"},
	"wide":{"size":Vector2(1760,600),"name":"横長工房"},
	"tall":{"size":Vector2(1120,1080),"name":"縦長工房"},
	"elbow":{"size":Vector2(1440,1000),"name":"L字工房"},
	"hall":{"size":Vector2(2240,1200),"name":"大広間"}
}
static func make_room(id: String, sides: Array, shape: String):
	var room = Shell.make_room(id,sides,SPECS[shape].size)
	room.field.spawns = PackedVector2Array([Vector2(170,SPECS[shape].size.y*.5)])
	if shape == "elbow":
		# Upper-right cutout, retaining all four cardinal door centers.
		var field = room.field
		var cut_x := 864.0
		var cut_y := 368.0
		for i in range(field.walls.size()-1,-1,-1):
			var rect: Rect2 = field.walls[i]
			if rect.position.y < 128:
				rect.size.x = maxf(0,minf(rect.end.x,cut_x+32)-rect.position.x)
			elif rect.position.x >= 1312 and rect.position.y < cut_y:
				var end := rect.end.y
				rect.position.y = cut_y
				rect.size.y = maxf(0,end-cut_y)
			if not rect.has_area():
				field.wall_materials.erase(field.wall_ids[i])
				field.wall_ids.remove_at(i)
				field.walls.remove_at(i)
			else: field.walls[i] = rect
		field.floor_regions[0] = Rect2(128,128,cut_x-128,cut_y-128)
		field.floor_regions.append(Rect2(128,cut_y,1184,544))
		Shell.wall(field,"elbow_side",Rect2(cut_x,128,32,cut_y-128),"top")
		Shell.wall(field,"elbow_face",Rect2(cut_x+32,cut_y-32,448,32),"face")
	return room

static func place(room, original, shape: String) -> void:
	var dimensions: Vector2 = SPECS[shape].size
	var prop = original.duplicate(true)
	# Move placement anchors, not textures/collision sizes: furniture keeps human scale.
	prop.position.x = 128+(original.position.x-128)*(dimensions.x-256)/864.0
	if original.position.y > 128:
		prop.position.y = 128+(original.position.y-128)*(dimensions.y-216)/384.0
	if shape == "elbow" and prop.position.x > 830 and prop.position.y < 405: return
	var collision := Rect2(prop.position+prop.collision.position,prop.collision.size)
	if collision.has_area():
		for point in [collision.position,collision.end,Vector2(collision.position.x,collision.end.y),Vector2(collision.end.x,collision.position.y)]:
			if not room.field.floor_contains(point): return
		for door in room.doors:
			if door.arrival.distance_to(door.arrival.clamp(collision.position,collision.end)) < 32: return
		var spawn: Vector2 = room.field.spawns[0]
		if spawn.distance_to(spawn.clamp(collision.position,collision.end)) < 32: return
	room.field.placements.append(prop)
