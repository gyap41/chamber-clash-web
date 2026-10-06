extends RefCounted
# Twenty authored rooms (docs/art/production/authored-rooms), with individually placed set pieces and cover.
# Opening support is explicit per template; junction-capable rooms accept cardinal subsets.
# Ordinary RoomTemplate/FieldDefinition data for the gallery and random art tour, not the combat floor.
const Shell = preload("res://scripts/world/workshop_room_shell.gd")
const Variants = preload("res://scripts/world/workshop_room_variants.gd")
const Dressing = preload("res://scripts/world/ashen_foundry_dressing.gd")
const Placement = preload("res://scripts/world/stage_placement.gd")
const Expansion = preload("res://scripts/world/authored_rooms_expansion.gd")
const ORDER := ["collapsed_gallery","casting_line","camp_remains","root_hall",
	"colonnade","courtyard","twin_halls","loading_bay","cistern","guard_post","fallen_gate",
	"vault","chapel","storage_cells","beast_nest","archive","repair_room","secret_room","overlook","antechamber"]
const NAMES := {"collapsed_gallery":"崩れた回廊","casting_line":"鋳造の作業列","camp_remains":"野営跡","root_hall":"根の広間",
	"colonnade":"列柱の広間","courtyard":"天井の抜けた中庭","twin_halls":"食い違う双広間",
	"loading_bay":"荷捌き場","cistern":"貯水槽のある部屋","guard_post":"見張り詰所","fallen_gate":"崩れた大門の間",
	"vault":"収蔵庫","chapel":"礼拝室","storage_cells":"小室が並ぶ保管区画","beast_nest":"生き物の巣",
	"archive":"埋もれた記録室","repair_room":"補修された小部屋","secret_room":"隠された脇室",
	"overlook":"地底を望む展望室","antechamber":"主の痕跡が残る前室","shop":"工房の露店"}
# 2026-10-06: reserve the whole shop layout before placing event stock; combat ruins hid the merchandise.
const SHOP_CENTER := Vector2(608,352)
const SHOP_MERCHANT := Vector2(204,320)
const SHOP_TELEPORTER := Vector2(352,560)
const SIZES := {"collapsed_gallery":Vector2(1120,800),"casting_line":Vector2(1440,960),
	"camp_remains":Vector2(1120,800),"root_hall":Vector2(1440,960),
	"twin_halls":Vector2(1440,960),"loading_bay":Vector2(1440,960),"storage_cells":Vector2(1440,800),"overlook":Vector2(1440,960),"secret_room":Vector2(1440,800)}
const LAMP_LIGHT := Color(1,.68,.36)
const FIRE_LIGHT := Color(1,.56,.26)
# Review 2026-09-27: rooms were evenly lit. Darkening only the floor made props float ("pasted"), so the whole
# room is dimmed together (theme ambient) and the lamp/furnace/fire lights brighten floor, props and actors.
const AMBIENT := Color(.8,.78,.76)
const MOSS_TINT := Color(.86,.86,.8,.9)
# Low pieces are seen mostly from the top: their whole drawn top is solid, not just a band at the feet.
const LOW_ARTS := ["rubble_large","rubble_small","material-crate","metal-pallet","anvil","tea_table","campfire","covered_crates"]
# Floor overlays (grit, cracks, dirt) sit into the floor rather than on it.
const OVERLAY_ALPHA := .6
const EXTERIOR = preload("res://assets/stages/ashen-foundry-v2/exterior-rock.png")
const COLLAPSE_KIT := "res://assets/stages/ashen-foundry-v2/gallery-collapse/%s.tres"

static func catalog() -> Dictionary:
	var rooms := {}
	for i in range(ORDER.size()):
		var id: String = ORDER[i]
		var room = make_room(id,["west","east"])
		for door in room.doors:
			var step := -1 if door.id == "west" else 1
			door.target_room = ORDER[posmod(i+step,ORDER.size())]
		rooms[id] = room
	return rooms

# Openings are centred on each wall and never rotate the art. Sides a room's set pieces occupy are withheld
# (opening audit 2026-09-30, docs/art/production/authored-rooms): chapel altar, archive records, overlook shaft,
# twin_halls partition, repair_room shoring and lamp face the north wall; the storage/secret bays fill north and south.
# Every other side combination is allowed, so rooms can turn and branch in any direction.
const DISCOVERIES := ["vault","archive","storage_cells","secret_room","chapel","overlook"]
const COMBAT_ROOMS := ["collapsed_gallery","casting_line","camp_remains","root_hall","colonnade","courtyard","twin_halls",
	"loading_bay","cistern","guard_post","fallen_gate","beast_nest","repair_room"]
const OPEN_SIDES := {"twin_halls":["south","west","east"],"repair_room":["south","west","east"],
	"chapel":["south","west","east"],"archive":["south","west","east"],"overlook":["south","west","east"],
	"storage_cells":["west","east"],"secret_room":["west","east"]}
static func open_sides(id: String) -> Array:
	return OPEN_SIDES.get(id,Shell.DIRECTIONS.keys())
static func connection_sets(id: String) -> Array:
	if id == "shop": return [["north"],["south"],["west"],["east"]]
	if id not in ORDER: return []
	if id == "antechamber": return [["west"],["east"],["west","east"],["north","west"],["north","east"],["north","south"]]
	var allowed := open_sides(id)
	var sets: Array = []
	# Discoveries are terminals on the floor: one entrance, from whichever permitted side. Their original
	# west-east pass-through remains for the room preview chain.
	if id in DISCOVERIES:
		for side in allowed: sets.append([side])
		sets.append(["west","east"])
		return sets
	var directions: Array = Shell.DIRECTIONS.keys()
	for mask in range(1,16):
		var sides: Array = []
		for i in range(4):
			if mask & (1 << i): sides.append(directions[i])
		if sides.all(func(side): return side in allowed): sets.append(sides)
	return sets

static func canonical_sides(sides: Array) -> Array:
	var result: Array = []
	for side in Shell.DIRECTIONS:
		if side in sides: result.append(side)
	return result

# Builds geometry independently of the preview order. The graph assembler assigns door targets.
static func make_room(id: String, sides: Array):
	assert(sides.size() == canonical_sides(sides).size() and canonical_sides(sides) in connection_sets(id),"Unsupported authored room openings: "+id+str(sides))
	return build_room(id,sides)

# Unchecked construction, used by make_room and by the opening audit that decides connection_sets.
static func build_room(id: String, sides: Array):
	var dimensions: Vector2 = SIZES.get(id,Vector2(1120,800))
	# These rooms keep their entrances at y560, below the northern discovery alcoves.
	var room = Shell.make_room(id,sides,Vector2(dimensions.x,1120) if id in ["storage_cells","secret_room"] else dimensions)
	if id in ["storage_cells","secret_room"]: compact_south(room,dimensions.y)
	room.display_name = NAMES[id] if id == "shop" else "%02d　%s" % [ORDER.find(id)+1,NAMES[id]]
	room.field.theme = Dressing.THEME.duplicate(true)
	room.field.theme.ambient = AMBIENT
	# Quiet the floor joints so the room's objects, light and routes carry the composition.
	room.field.theme.floor_wash = Color(.24,.225,.19,.12)
	room.field.spawns = PackedVector2Array([Vector2(170,dimensions.y*.5)])
	match id:
		"shop": shop(room)
		"collapsed_gallery": collapsed_gallery(room)
		"casting_line": casting_line(room)
		"camp_remains": camp_remains(room)
		"root_hall": root_hall(room)
		_: Expansion.build(load("res://scripts/world/authored_rooms.gd"),room,id)

	# A one-ended room must spawn at its actual opening, including east-only variants.
	room.field.spawns = PackedVector2Array([room.doors[0].arrival])
	return room

static func shop(room) -> void:
	exterior(room)
	# Storage stays against the north wall, leaving its central doorway and the entire sales floor clear.
	for x in [300,820]:
		var shelf = put(room,"shop_shelf_%d" % x,Expansion.KIT % "archive_shelf",Vector2(x,204),150,24)
		shelf.wall_shadow = true
		lamp(room,x)

# Shorten unused southern floor without moving side entrances or scaling furniture.
static func compact_south(room, height: float) -> void:
	var field = room.field
	var bottom := height-88
	for i in range(field.walls.size()):
		var rect: Rect2 = field.walls[i]
		if field.wall_ids[i] == "south": rect.position.y = bottom
		elif rect.end.y > bottom: rect.size.y = bottom-rect.position.y
		field.walls[i] = rect
	var clipped: Array[Rect2] = []
	for rect in field.floor_regions:
		var area: Rect2 = rect.intersection(Rect2(0,0,field.field_rect.size.x,bottom))
		if area.has_area(): clipped.append(area)
	field.floor_regions = clipped
	field.field_rect.size.y = height
	field.fighter_bounds.size.y = height-142
	field.projectile_bounds.size.y = height-67

# Floor-standing piece: `feet` is where it meets the floor; `depth` > 0 adds a collision band above the feet.
# `shadow_lift` raises the contact shadow for pieces whose drawn body sits above their lowest pixels (root trunk).
static func put(room, id: String, art: String, feet: Vector2, width: float, depth: float = 0.0, flip: bool = false, shadow_lift: float = 0.0):
	var prop = Placement.new()
	prop.placement_id = "authored_"+id
	prop.texture = load(art if art.begins_with("res://") else Dressing.PROPS_V2 % art)
	var height: float = width*prop.texture.get_height()/prop.texture.get_width()
	prop.position = feet
	prop.visual_rect = Rect2(-width*.5,-height,width,height)
	if depth > 0:
		var solid: float = height*.8 if art in LOW_ARTS else depth
		prop.collision = Rect2(-width*.44,-solid,width*.88,solid)
		prop.contact_shadow = true
		prop.shadow_rect = Rect2(-width*.42,-8-shadow_lift,width*.84,8)
		prop.drop_shadow = true
	prop.flip_h = flip
	if art == "quench_trough": prop.water_surface = Rect2(.13,.36,.57,.27)
	if art == "lamp": prop.fire_kind = 1
	if art == "campfire": prop.fire_kind = 2
	if art == "furnace": prop.fire_kind = 3
	room.field.placements.append(prop)
	return prop

# Invisible solid rectangle (world coordinates) for pieces drawn as floor or wall overlays that read as
# obstacles: raised channels, sunken roots, masonry spilled from a wall.
static func block(room, id: String, rect: Rect2) -> void:
	var prop = Placement.new()
	prop.placement_id = "authored_block_"+id
	prop.position = rect.get_center()
	prop.visual_rect = Rect2(-rect.size*.5,rect.size)
	prop.collision = Rect2(-rect.size*.5,rect.size)
	room.field.placements.append(prop)

# Raised flat piece: drawn on the floor with a soft shadow, solid along its length in `parts` segments.
# `thickness` is the solid share of the drawn height; `offsets` shift each segment vertically (curving roots).
static func raised(room, id: String, art: String, center: Vector2, width: float, thickness: float, flip: bool = false, offsets: Array = [0.0]):
	var prop = flat(room,id,art,center,width,1.0,flip)
	prop.drop_shadow = true
	var height: float = prop.visual_rect.size.y
	var parts := offsets.size()
	for i in range(parts):
		var x0: float = center.x-width*.46+width*.92*i/parts
		var dy: float = offsets[i] if not flip else offsets[parts-1-i]
		block(room,"%s_%d" % [id,i],Rect2(x0,center.y-height*thickness*.5+dy,width*.92/parts,height*thickness))
	return prop

# Flat floor piece centred on `center`, drawn under actors.
static func flat(room, id: String, art: String, center: Vector2, width: float, alpha: float = 1.0, flip: bool = false):
	var prop = Placement.new()
	prop.placement_id = "authored_"+id
	prop.texture = load(art if art.begins_with("res://") else Dressing.PROPS_V2 % art)
	var height: float = width*prop.texture.get_height()/prop.texture.get_width()
	prop.position = center
	prop.visual_rect = Rect2(-width*.5,-height*.5,width,height)
	prop.floor_decal = true
	prop.tint = Color(1,1,1,alpha)
	prop.flip_h = flip
	room.field.placements.append(prop)
	return prop

static func moss(room, center: Vector2, width: float, flip: bool = false) -> void:
	flat(room,"moss_%d_%d" % [center.x,center.y],"moss",center,width,1.0,flip).tint = MOSS_TINT

# Warm translucent light pool painted on the floor (under actors), radius in world px.
static func glow(room, center: Vector2, radius: float, strength: float = .22, color: Color = LAMP_LIGHT) -> void:
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color(color,strength),Color(color,strength*.45),Color(color,0)])
	gradient.offsets = PackedFloat32Array([0,.45,1])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 128
	texture.height = 128
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(.5,.5)
	texture.fill_to = Vector2(1,.5)
	var prop = Placement.new()
	prop.placement_id = "authored_glow_%d" % room.field.placements.size()
	prop.texture = texture
	prop.position = center
	prop.visual_rect = Rect2(-radius,-radius*.75,radius*2,radius*1.5)
	prop.floor_decal = true
	room.field.placements.append(prop)

# Iron lamp on a north wall face at x (the wall face runs y 80..128 in the shell), with its light pool.
static func lamp(room, x: float, y: float = 118.0) -> void:
	var prop = put(room,"lamp_%d" % room.field.placements.size(),"lamp",Vector2(x,y),18)
	prop.light_radius = 130
	prop.light_energy = .62
	prop.light_color = LAMP_LIGHT
	prop.light_offset = Vector2(0,-20)
	glow(room,Vector2(x,y+50),110,.1)

# Root coming out of a wall, drawn over the masonry but under every actor. Returns the drawn rectangle.
static func root(room, art: String, top_left: Vector2, width: float, flip: bool = false) -> Rect2:
	var prop = Placement.new()
	prop.placement_id = "authored_%s_%d" % [art,room.field.placements.size()]
	prop.texture = load(Dressing.PROPS_V2 % art)
	var height: float = width*prop.texture.get_height()/prop.texture.get_width()
	prop.visual_rect = Rect2(-width*.5,-height,width,height)
	prop.position = top_left+Vector2(width*.5,height)
	prop.surface_overlay = true
	prop.flip_h = flip
	room.field.placements.append(prop)
	return Rect2(top_left,Vector2(width,height))

# By a side wall (seen only from above) a root breaks up through the floor along the wall's foot; roots only
# come out of a wall where its front face shows (north walls).
static func side_root(room, top_left: Vector2, width: float) -> void:
	var center := Vector2(128+width*.55,top_left.y+width*.3)
	raised(room,"floor_root_%d" % room.field.placements.size(),"sunken_root_fork",center,width*1.1,.4,false,[-8.0,6.0])

static func exterior(room) -> void:
	room.field.theme.exterior_texture = EXTERIOR
	room.field.theme.exterior_tint = Color(.9,.9,.9)

# North-wall feature (breach, roots through the wall) without its own masonry, so the real wall shows around
# it: the top of the wall cap is at y 44 in the shell.
# Whatever the picture draws below the wall line (y 128), such as spilled masonry or root feet, is solid.
static func on_north_wall(room, art: String, x: float, width: float, flip: bool = false) -> void:
	var drawn := root(room,art+"_core",Vector2(x,44),width,flip)
	var below := drawn.end.y-128
	if below > 8:
		block(room,"%s_foot_%d" % [art,x],Rect2(x+width*.18,128,width*.64,below*.8))



static func dirt(room, center: Vector2, width: float) -> void:
	flat(room,"dirt_%d_%d" % [center.x,center.y],"dirt_strip",center,width,OVERLAY_ALPHA*.8)

# Local debris belongs to a source, rather than being a repeating decoration across the open floor.
static func debris(room, id: String, center: Vector2, width: float, flip: bool = false) -> void:
	flat(room,id+"_grit","pebbles_b",center,width,.38,flip)
	flat(room,id+"_crack","floor_crack",center+Vector2(12,10),width*.8,.34,not flip)

static func casting_bed(room, id: String, center: Vector2, width: float, flip: bool = false) -> void:
	# The source art has closed ends: these are separate sand casting beds, not connected pipes.
	raised(room,id,"casting_channel",center,width,.68,flip)
	flat(room,id+"_soot","soot_streaks",center+Vector2(-width*.28,42),width*.58,.32,flip)

static func collapsed_gallery(room) -> void:
	# Original building: three structural axes along an east-west gallery, with a colonnade on each side.
	# The northern middle support/roof has collapsed across the aisle. Two bypasses remain around the fall.
	exterior(room)
	Variants.cut_corner(room.field,"nw",248,252)
	Variants.cut_corner(room.field,"se",872,588)
	room.field.theme.ambient = Color(.77,.78,.79)
	# Wall piers line up with the internal supports: the repeated spacing belongs to the original building.
	for x in [300,820]:
		put(room,"buttress_%d" % x,"buttress",Vector2(x,152),54,18)
		put(room,"north_column_%d" % x,"pillar",Vector2(x,292),46,34)
		put(room,"south_column_%d" % x,"pillar",Vector2(x,582),46,34)
	# The surviving southern parapet establishes the old aisle. Its broken end opens onto the bypass.
	put(room,"south_parapet","wall_segment_mid",Vector2(413,582),190,28)
	var south_base = put(room,"south_base",COLLAPSE_KIT % "broken_base",Vector2(560,590),64,30)
	south_base.collision = Rect2(-23,-37,46,37)
	south_base.tint = Color(.90,.93,.96)
	flat(room,"south_break_crack","floor_crack",Vector2(540,580),74,.55,true)
	# The northern parapet ends at the fallen support, rather than floating as an isolated object.
	put(room,"north_parapet","wall_segment_short",Vector2(754,292),130,26,true)
	var north_base = put(room,"fallen_support",COLLAPSE_KIT % "broken_base",Vector2(560,296),64,30)
	north_base.collision = Rect2(-23,-37,46,37)
	north_base.tint = Color(.90,.93,.96)
	# Damage follows the southeast fall, with the impact under the heavy members, not a carpet of grit.
	flat(room,"fall_crack","floor_crack",Vector2(582,321),104,.72)
	flat(room,"roof_impact_crack","floor_crack",Vector2(612,420),184,.78,true)
	# The dedicated kit shows the missing support and large broken roof members. Stepped solids follow
	# their low diagonal footprints instead of blocking the transparent corners of each atlas rectangle.
	var shaft = put(room,"fallen_shaft",COLLAPSE_KIT % "fallen_shaft",Vector2(584,376),112,1)
	shaft.collision = Rect2()
	shaft.tint = Color(.88,.92,.96)
	shaft.shadow_rect = Rect2(-34,-53,68,40)
	for part in [Rect2(-48,-82,44,35),Rect2(-24,-60,46,39),Rect2(10,-32,40,28)]:
		block(room,"shaft_%d" % room.field.placements.size(),Rect2(shaft.position+part.position,part.size))
	var roof = put(room,"fallen_roof",COLLAPSE_KIT % "roof_collapse",Vector2(600,440),172,1)
	roof.collision = Rect2()
	roof.tint = Color(.88,.92,.96)
	roof.shadow_rect = Rect2(-70,-48,139,40)
	for part in [Rect2(-78,-65,100,36),Rect2(-30,-69,79,57),Rect2(40,-35,34,28)]:
		block(room,"roof_%d" % room.field.placements.size(),Rect2(roof.position+part.position,part.size))
	flat(room,"fall_fragments",COLLAPSE_KIT % "fragments",Vector2(643,462),64,.9).tint = Color(.88,.92,.96,.9)
	flat(room,"fall_scatter","pebbles_a",Vector2(590,457),72,.42,true)
	# Skylight from the roof failure: a broad restrained cool source, separate from the warm wall lamps.
	var skylight = Placement.new()
	skylight.placement_id = "authored_roof_light"
	skylight.position = Vector2(553,310)
	skylight.visual_rect = Rect2(-1,-1,2,2)
	var transparent := Gradient.new()
	transparent.colors = PackedColorArray([Color.TRANSPARENT,Color.TRANSPARENT])
	var transparent_texture := GradientTexture2D.new()
	transparent_texture.gradient = transparent
	skylight.texture = transparent_texture
	skylight.light_radius = 245
	skylight.light_energy = .48
	skylight.light_color = Color(.68,.8,1.0)
	room.field.placements.append(skylight)
	glow(room,Vector2(553,318),175,.09,Color(.62,.76,1))
	# Damp growth remains at the damaged roof bay, away from the dry central travelling lanes.
	flat(room,"damp_moss","moss_long",Vector2(563,169),154,.5).tint = MOSS_TINT
	dirt(room,Vector2(558,150),215)
	lamp(room,348)
	lamp(room,874)

static func casting_line(room) -> void:
	# Pouring in the north-west, cooling in the east, finishing in the south-west.
	# Two separate casting beds leave a broad dog-leg service route through the workshop.
	exterior(room)
	Variants.cut_corner(room.field,"ne",1120,304)
	var furnace = put(room,"furnace","furnace",Vector2(295,204),112,52)
	furnace.light_radius = 260
	furnace.light_energy = .82
	furnace.light_color = FIRE_LIGHT
	furnace.light_offset = Vector2(0,-40)
	furnace.wall_shadow = true
	furnace.wall_flue = true
	glow(room,Vector2(320,258),200,.22,FIRE_LIGHT)
	flat(room,"soot","soot_streaks",Vector2(320,246),165,.4)
	put(room,"mold_rack","mold_rack",Vector2(486,196),145,40).wall_shadow = true
	put(room,"cabinet","cabinet",Vector2(1008,186),66,40).wall_shadow = true
	dirt(room,Vector2(412,149),290)
	casting_bed(room,"pouring_bed",Vector2(447,320),330)
	put(room,"pouring_stock","metal-pallet",Vector2(240,340),74,30)
	put(room,"pouring_anvil","anvil",Vector2(548,418),60,24)
	flat(room,"pouring_offcuts","offcuts",Vector2(575,441),55,.8)
	# The cold bed is offset, with the quench tank and finished stock beside its outlet end.
	casting_bed(room,"cooling_bed",Vector2(960,613),310,true)
	put(room,"trough","quench_trough",Vector2(1110,730),115,36)
	put(room,"cooling_stock","metal-pallet",Vector2(1168,605),78,32,true)
	put(room,"cooling_crate","material-crate",Vector2(1196,678),60,28)
	# Finishing bench: tools and offcuts are confined to the working side.
	put(room,"bench","bench",Vector2(404,687),134,34)
	put(room,"finishing_anvil","anvil",Vector2(535,711),60,24,true)
	put(room,"finishing_stock","metal-pallet",Vector2(291,690),80,32)
	put(room,"finishing_crate","material-crate",Vector2(280,765),58,26)
	flat(room,"finishing_offcuts","offcuts",Vector2(480,735),65,.78,true)
	flat(room,"finishing_scuff","soot_streaks",Vector2(422,730),172,.24,true)
	# Stores occupy the recessed corner, with space in front to unload them.
	put(room,"stores","covered_crates",Vector2(1223,364),84,34)
	put(room,"store_crate","material-crate",Vector2(1150,389),60,28,true)
	lamp(room,575)
	lamp(room,940)

static func camp_remains(room) -> void:
	# A warm inhabited pocket beneath a ruined partition; the eastern half remains a travelling lane.
	exterior(room)
	Variants.cut_corner(room.field,"sw",352,560)
	room.field.theme.ambient = Color(.76,.75,.74)
	put(room,"shelter_wall","wall_segment_long",Vector2(430,280),300,28)
	debris(room,"shelter_end",Vector2(303,302),90)
	var fire = put(room,"campfire","campfire",Vector2(492,441),64,20)
	fire.light_radius = 295
	fire.light_energy = .82
	fire.light_color = FIRE_LIGHT
	fire.light_offset = Vector2(0,-24)
	glow(room,Vector2(492,433),240,.23,FIRE_LIGHT)
	flat(room,"fire_soot","soot_streaks",Vector2(491,449),115,.35,true)
	flat(room,"rug","rug",Vector2(380,350),155,.85)
	put(room,"tea","tea_table",Vector2(351,366),54,22)
	flat(room,"bedroll_west","bedroll",Vector2(367,453),72)
	flat(room,"bedroll_south","bedroll",Vector2(460,551),72,1.0,true)
	flat(room,"bedroll_east","bedroll",Vector2(604,521),72)
	# Supplies are within reach of the camp, irregularly stacked against the surviving partition.
	put(room,"stores","covered_crates",Vector2(642,306),84,34)
	put(room,"crate_a","material-crate",Vector2(698,355),58,28)
	put(room,"crate_b","material-crate",Vector2(683,407),48,24,true)
	dirt(room,Vector2(335,147),180)
	# The ruined corner belongs to the abandoned half of the shelter.
	put(room,"fallen_corner","rubble_large",Vector2(410,657),90,26)
	debris(room,"fallen_corner",Vector2(434,631),120,true)
	flat(room,"corner_moss","moss_clumps",Vector2(431,684),94,.62)
	raised(room,"unused_root","sunken_root_fork",Vector2(850,220),170,.4,true,[-5.0,7.0])
	flat(room,"root_moss","moss_long",Vector2(896,260),125,.65).tint = MOSS_TINT
	flat(room,"nest","root_nest",Vector2(937,206),58,.8,true)
	lamp(room,350)

static func root_hall(room) -> void:
	# One advancing seam of roots from the west, terminating at a broken column. The southern floor is a
	# continuous bypass; the roots' northern side remains accessible via the east end and a western gap.
	exterior(room)
	Variants.cut_corner(room.field,"se",1136,720)
	room.field.theme.floor_tint = Color(.64,.72,.64)
	room.field.theme.wall_tint = Color(1.04,1.07,.96)
	on_north_wall(room,"wall_roots",236,140)
	flat(room,"source_moss","moss_long",Vector2(324,200),210,.72).tint = MOSS_TINT
	flat(room,"source_growth","moss_clumps",Vector2(302,248),110,.65).tint = MOSS_TINT
	# Overlapping ends form a single stepped seam, without rotating directionally lit sprites.
	raised(room,"root_source","sunken_root_fork",Vector2(285,327),220,.4,false,[-6.0,7.0])
	raised(room,"root_trunk","sunken_root",Vector2(525,355),350,.46,false,[-5.0,6.0,-6.0,4.0])
	raised(room,"root_tip","sunken_root_fork",Vector2(746,366),220,.44,true,[-8.0,5.0,9.0])
	for patch in [[Vector2(380,383),126],[Vector2(600,398),135],[Vector2(819,411),95]]:
		flat(room,"seam_moss_%d" % patch[0].x,"moss_clumps",patch[0],patch[1],.58).tint = MOSS_TINT
	debris(room,"root_tip",Vector2(867,418),130,true)
	put(room,"pillar_broken","pillar",Vector2(887,405),46,34)
	put(room,"pillar_rubble","rubble_small",Vector2(924,435),62,18)
	flat(room,"nest_source","root_nest",Vector2(247,235),64,.85)
	# A second surviving column marks the original aisle; collapse debris remains at its foot.
	put(room,"aisle_remnant","wall_segment_short",Vector2(965,669),145,26,true)
	put(room,"aisle_heap","rubble_small",Vector2(1042,693),60,18)
	debris(room,"aisle",Vector2(1020,711),118)
	flat(room,"aisle_moss","moss_long",Vector2(977,711),145,.65).tint = MOSS_TINT
	put(room,"buttress_west","buttress",Vector2(525,152),54,18)
	put(room,"buttress_east","buttress",Vector2(935,152),54,18,true)
	dirt(room,Vector2(315,145),275)
	lamp(room,1040)
	# Abandoned belongings at the bypass entrance suggest an interrupted expedition.
	put(room,"abandoned_crate","material-crate",Vector2(300,741),58,26)
	flat(room,"abandoned_bedroll","bedroll",Vector2(358,752),70,.78,true)
