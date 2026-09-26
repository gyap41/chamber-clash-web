extends RefCounted
const Shell = preload("res://scripts/world/workshop_room_shell.gd")
const NORMAL_SHAPES := ["standard","wide","tall","elbow","west_annex","east_annex","offset","reverse_offset","cross","north_wing","south_wing","alcove","partitioned","pillared"]
const SPECS := {
	"standard":{"size":Vector2(1120,600),"name":"標準工房"},
	"compact":{"size":Vector2(880,600),"name":"小作業室"},
	"wide":{"size":Vector2(1760,600),"name":"横長工房"},
	"tall":{"size":Vector2(1120,1080),"name":"縦長工房"},
	"elbow":{"size":Vector2(1440,1000),"name":"L字工房"},
	"hall":{"size":Vector2(2240,1200),"name":"大広間"},
	"west_annex":{"size":Vector2(1440,960),"name":"西張出し工房","cuts":[["ne",960,304],["se",1088,656]],"pillars":[Vector2(528,368),Vector2(864,656)]},
	"east_annex":{"size":Vector2(1440,960),"name":"東張出し工房","cuts":[["nw",448,320],["sw",352,640]]},
	"offset":{"size":Vector2(1440,960),"name":"食違い工房","cuts":[["nw",480,336],["se",992,656]]},
	"reverse_offset":{"size":Vector2(1440,960),"name":"逆折れ工房","cuts":[["ne",944,304],["sw",400,624]]},
	"cross":{"size":Vector2(1440,960),"name":"交差作業室","cuts":[["nw",400,304],["ne",1008,336],["sw",480,672],["se",1056,624]]},
	"north_wing":{"size":Vector2(1440,960),"name":"北棟作業室","cuts":[["sw",480,624],["se",1008,688]],"pillars":[Vector2(528,368),Vector2(944,368)]},
	"south_wing":{"size":Vector2(1440,960),"name":"南棟作業室","cuts":[["nw",416,336],["ne",976,288]]},
	"alcove":{"size":Vector2(1440,960),"name":"鉤形作業室","cuts":[["nw",480,336]]},
	"partitioned":{"size":Vector2(1440,960),"name":"仕切り工房","cuts":[["nw",352,288]],"partitions":[Rect2(600,280,32,240),Rect2(864,640,256,32)]},
	"pillared":{"size":Vector2(1440,960),"name":"列柱作業室","cuts":[["ne",1056,304]],"pillars":[Vector2(496,360),Vector2(896,360),Vector2(496,664),Vector2(896,664)]}
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
	for cut in SPECS[shape].get("cuts",[]): cut_corner(room.field,cut[0],cut[1],cut[2])
	for rect in SPECS[shape].get("partitions",[]):
		Shell.wall(room.field,"partition_%d" % room.field.walls.size(),rect,"face" if rect.size.x > rect.size.y else "top")
	for at in SPECS[shape].get("pillars",[]): add_pillar(room.field,at)
	return room

static func place(room, original, shape: String) -> void:
	var dimensions: Vector2 = SPECS[shape].size
	var prop = original.duplicate(true)
	# Move placement anchors, not textures/collision sizes: furniture keeps human scale.
	prop.position.x = 128+(original.position.x-128)*(dimensions.x-256)/864.0
	if original.position.y > 128:
		prop.position.y = 128+(original.position.y-128)*(dimensions.y-216)/384.0
	if shape == "elbow" and prop.position.x > 830 and prop.position.y < 405: return
	# Wall fixtures require an actual front wall at their attachment point.
	if original.wall_shadow or original.light_radius > 0:
		var supported := false
		for i in range(room.field.walls.size()):
			var wall: Rect2 = room.field.walls[i]
			if room.field.wall_materials.get(room.field.wall_ids[i]) == "face" and prop.position.x >= wall.position.x+16 and prop.position.x <= wall.end.x-16 and absf(prop.position.y-wall.end.y) < 110:
				supported = true
		if not supported: return
	var collision := Rect2(prop.position+prop.collision.position,prop.collision.size)
	if collision.has_area():
		for point in [collision.position,collision.end,Vector2(collision.position.x,collision.end.y),Vector2(collision.end.x,collision.position.y)]:
			if not room.field.floor_contains(point): return
		for wall in room.field.walls:
			if wall.grow(12).intersects(collision): return
		for other in room.field.placements:
			if other.collision.has_area() and Rect2(other.position+other.collision.position,other.collision.size).grow(16).intersects(collision): return
			if other.placement_id.begins_with("structural_pillar") and Rect2(other.position+other.visual_rect.position,other.visual_rect.size).grow(12).intersects(Rect2(prop.position+prop.visual_rect.position,prop.visual_rect.size)): return
		for door in room.doors:
			if door.arrival.distance_to(door.arrival.clamp(collision.position,collision.end)) < 32: return
		var spawn: Vector2 = room.field.spawns[0]
		if spawn.distance_to(spawn.clamp(collision.position,collision.end)) < 32: return
	room.field.placements.append(prop)

# Rectangular cutouts preserve the four cardinal opening corridors.
# Floor and shell are cut together; the exposed returns share the existing wall kit.
static func cut_corner(field, corner: String, x: float, y: float) -> void:
	var size: Vector2 = field.field_rect.size
	var west := corner.ends_with("w")
	var north := corner.begins_with("n")
	var cut := Rect2(0 if west else x,0 if north else y,x if west else size.x-x,y if north else size.y-y)
	var subtract = preload("res://scripts/world/connected_wall_surface.gd")
	var regions: Array[Rect2] = []
	for rect in field.floor_regions: regions.append_array(subtract.subtract_rect(rect,cut))
	field.floor_regions = regions
	var old_walls: Array = field.walls.duplicate()
	var ids: PackedStringArray = field.wall_ids.duplicate()
	var materials: Dictionary = field.wall_materials.duplicate()
	field.walls.clear()
	field.wall_ids.clear()
	field.wall_materials.clear()
	for i in range(old_walls.size()):
		var pieces: Array[Rect2] = subtract.subtract_rect(old_walls[i],cut)
		for j in range(pieces.size()): Shell.wall(field,ids[i]+"_%d" % j,pieces[j],materials[ids[i]])
	var right := size.x-128
	var bottom := size.y-88
	Shell.wall(field,corner+"_return",Rect2(x-32 if west else x,128 if north else y,32,y-128 if north else bottom-y),"top")
	Shell.wall(field,corner+"_ledge",Rect2(96 if west else x,y-48 if north else y,x-96 if west else right+32-x,48 if north else 32),"face" if north else "top")

static func add_pillar(field, at: Vector2) -> void:
	var prop = preload("res://scripts/world/stage_placement.gd").new()
	var texture := AtlasTexture.new()
	texture.atlas = preload("res://assets/stages/ashen-foundry/collapse-v1/pillars.png")
	texture.region = Rect2(215,106,382,784)
	texture.filter_clip = true
	prop.placement_id = "structural_pillar_%d" % field.placements.size()
	prop.position = at
	prop.texture = texture
	prop.visual_rect = Rect2(-24,-96,48,98.5)
	prop.collision = Rect2(-22,-18,44,34)
	prop.contact_shadow = true
	prop.shadow_rect = Rect2(-30,-12,60,25)
	prop.tint = Color(.76,.74,.69)
	field.placements.append(prop)
