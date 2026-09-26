extends RefCounted
# An authored review room: not yet part of the random floor pool.
const Shell = preload("res://scripts/world/workshop_room_shell.gd")
const Placement = preload("res://scripts/world/stage_placement.gd")
const THEME = preload("res://data/stage_themes/ashen_foundry.tres")
const LAMP = preload("res://assets/first-workshop/showcase/lamp.png")

static func prop(field, id: String, at: Vector2, texture: Texture2D, visual: Rect2, collision: Rect2 = Rect2()):
	var item = Placement.new()
	item.placement_id = id
	item.position = at
	item.texture = texture
	item.visual_rect = visual
	item.collision = collision
	field.placements.append(item)
	return item

static func atlas(texture: Texture2D, region: Rect2) -> AtlasTexture:
	var result := AtlasTexture.new()
	result.atlas = texture
	result.region = region
	result.filter_clip = true
	return result

static func catalog() -> Dictionary:
	var room = Shell.make_room("collapsed_workshop",["south"],Vector2(1120,700))
	room.display_name = "崩落した作業室"
	var field = room.field
	field.theme = THEME.duplicate(true)
	field.walls.clear()
	field.wall_ids.clear()
	field.wall_materials.clear()
	field.floor_regions.assign([Rect2(224,128,784,484),Rect2(80,288,144,176),Rect2(488,612,144,32)])
	field.spawns = PackedVector2Array([Vector2(520,460)])
	Shell.wall(field,"north",Rect2(192,80,560,48),"face")
	Shell.wall(field,"west_upper",Rect2(192,128,32,160),"top")
	Shell.wall(field,"annex_north",Rect2(48,256,144,32),"face")
	Shell.wall(field,"annex_west",Rect2(48,288,32,176),"top")
	Shell.wall(field,"annex_south",Rect2(48,464,176,32),"top")
	Shell.wall(field,"west_lower",Rect2(192,496,32,116),"top")
	Shell.wall(field,"south_left",Rect2(192,612,296,32),"top")
	Shell.wall(field,"south_right",Rect2(632,612,408,32),"top")
	Shell.wall(field,"east",Rect2(1008,390,32,222),"top")
	# North-east terrain fills the missing shell. Sprite and collision are separate.
	var rubble: Texture2D = load("res://assets/stages/ashen-foundry/collapse-v1/collapse-ne.png")
	var bank = prop(field,"collapse_bank",Vector2(700,48),rubble,Rect2(0,0,360,360))
	bank.surface_overlay = true
	bank.tint = Color(.74,.72,.67)
	# Broad strips approximate the diagonal interior; no per-pebble collisions.
	for i in range(8):
		var x := 744.0+i*40
		var height := x-710
		prop(field,"collapse_solid_%d" % i,Vector2(x,48),null,Rect2(0,0,40,height),Rect2(0,0,40,height))
	var sheet: Texture2D = load("res://assets/stages/ashen-foundry/collapse-v1/pillars.png")
	var intact := atlas(sheet,Rect2(215,106,382,784))
	var broken := atlas(sheet,Rect2(867,427,533,482))
	var a = prop(field,"pillar_west",Vector2(430,320),intact,Rect2(-28,-117,57.3,117.6),Rect2(-26,-20,52,38))
	a.contact_shadow = true
	a.tint = Color(.76,.74,.69)
	a.shadow_rect = Rect2(-34,-14,68,30)
	var b = prop(field,"pillar_east",Vector2(810,495),intact,Rect2(-28,-117,57.3,117.6),Rect2(-26,-20,52,38))
	b.contact_shadow = true
	b.tint = Color(.76,.74,.69)
	b.shadow_rect = Rect2(-34,-14,68,30)
	var stump = prop(field,"broken_pillar",Vector2(680,260),broken,Rect2(-33,-62,79.95,72.3),Rect2(-26,-15,52,30))
	stump.contact_shadow = true
	stump.tint = Color(.76,.74,.69)
	stump.shadow_rect = Rect2(-33,-12,66,27)
	for pos in [Vector2(300,123),Vector2(145,290),Vector2(615,123)]:
		var lamp = prop(field,"lamp_%d" % field.placements.size(),pos,LAMP,Rect2(-12,-32,24,42))
		lamp.light_radius = 145
		lamp.light_energy = .55
		lamp.light_offset = Vector2(0,-6)
	var dressing = preload("res://scripts/world/ashen_foundry_dressing.gd")
	dressing.decal(field,"collapse_dust",1,Vector2(820,250),Vector2(360,270))
	field.placements.back().tint = Color(1,1,1,.5)
	dressing.decal(field,"annex_scuff",3,Vector2(155,385),Vector2(95,70))
	field.placements.back().tint = Color(1,1,1,.55)
	var hall = Shell.make_room("collapse_approach",["north"],Vector2(880,600))
	hall.display_name = "作業室への通路"
	hall.field.theme = THEME.duplicate(true)
	room.doors[0].target_room = "collapse_approach"
	hall.doors[0].target_room = "collapsed_workshop"
	return {"collapsed_workshop":room,"collapse_approach":hall}
