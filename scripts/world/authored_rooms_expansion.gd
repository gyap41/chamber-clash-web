extends RefCounted
# Sixteen individually composed rooms extending the four accepted/trial rooms. Art resources are shared,
# but footprints, sight lines, original use and discovery positions are authored separately.
const KIT := "res://assets/stages/ashen-foundry-v2/exploration-kit/%s.tres"

static func prop(a, room, id: String, art: String, x: float, y: float, width: float, depth: float = 24.0):
	return a.put(room,id,art,Vector2(x,y),width,depth)

static func kit(a, room, id: String, art: String, x: float, y: float, width: float, low: bool = true):
	var p = a.put(room,id,KIT % art,Vector2(x,y),width,1)
	var h: float = p.visual_rect.size.y
	p.collision = Rect2(-width*.46,-h*(.94 if low else .22),width*.92,h*(.94 if low else .22))
	p.shadow_rect = Rect2(-width*.38,-h*.28,width*.76,h*.24)
	p.tint = Color(.91,.94,.96)
	return p

static func decal(a, room, id: String, art: String, x: float, y: float, width: float, alpha: float = .8):
	return a.flat(room,id,KIT % art,Vector2(x,y),width,alpha)

static func column(a, room, x: float, y: float) -> void:
	prop(a,room,"column_%d_%d" % [x,y],"pillar",x,y,46,34)

static func low_wall(a, room, id: String, x: float, y: float, width: float, flip: bool = false) -> void:
	a.put(room,id,"wall_segment_long" if width > 210 else "wall_segment_mid",Vector2(x,y),width,28,flip)

static func cool_light(a, room, center: Vector2, radius: float, energy: float = .38) -> void:
	# Transparent source: illumination belongs to the room, not the source PNG.
	var p = a.Placement.new()
	p.placement_id = "authored_daylight_%d" % room.field.placements.size()
	p.position = center
	p.visual_rect = Rect2(-1,-1,2,2)
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color.TRANSPARENT,Color.TRANSPARENT])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	p.texture = texture
	p.light_radius = radius
	p.light_energy = energy
	p.light_color = Color(.72,.84,1)
	room.field.placements.append(p)
	a.glow(room,center,radius*.7,.08,Color(.65,.82,1))

static func build(a, room, id: String) -> void:
	a.exterior(room)
	match id:
		"colonnade": colonnade(a,room)
		"courtyard": courtyard(a,room)
		"twin_halls": twin_halls(a,room)
		"loading_bay": loading_bay(a,room)
		"cistern": cistern(a,room)
		"guard_post": guard_post(a,room)
		"fallen_gate": fallen_gate(a,room)
		"vault": vault(a,room)
		"chapel": chapel(a,room)
		"storage_cells": storage_cells(a,room)
		"beast_nest": beast_nest(a,room)
		"archive": archive(a,room)
		"repair_room": repair_room(a,room)
		"secret_room": secret_room(a,room)
		"overlook": overlook(a,room)
		"antechamber": antechamber(a,room)

static func colonnade(a, r) -> void:
	# Formal north/south rows, central east-west sight line; one missing support opens a diagonal crossing.
	for x in [330,560,790]:
		column(a,r,x,310)
		if x != 560 or not r.doors.any(func(d): return d.id == "north"):
			prop(a,r,"buttress_%d" % x,"buttress",x,152,54,18)
	for x in [330,790]: column(a,r,x,580)
	prop(a,r,"broken_column",a.COLLAPSE_KIT % "broken_base",560,580,64,36)
	a.flat(r,"fracture","floor_crack",Vector2(570,584),110,.7)
	low_wall(a,r,"west_remnant",270,650,150)
	kit(a,r,"record","tablet",830,195,74,false)
	a.lamp(r,435)
	a.lamp(r,685)
	cool_light(a,r,Vector2(555,480),190,.24)

static func courtyard(a, r) -> void:
	# Clear central court; soil grows inward from one perimeter, never a centre obstacle.
	r.field.theme.ambient = Color(.84,.86,.80)
	a.Variants.cut_corner(r.field,"ne",880,252)
	decal(a,r,"soil_west","soil_roots",295,280,265,.92)
	decal(a,r,"soil_south","soil_roots",383,610,220,.88).flip_h = true
	a.raised(r,"garden_root",KIT % "floor_root",Vector2(273,285),200,.36,false,[-5.0,6.0])
	for p in [Vector2(470,250),Vector2(790,580)]: column(a,r,p.x,p.y)
	low_wall(a,r,"garden_edge",388,645,190)
	a.moss(r,Vector2(295,188),155)
	a.moss(r,Vector2(820,640),108,true)
	prop(a,r,"fallen_stone","rubble_small",845,258,72,20)
	kit(a,r,"garden_seat","plinth",850,615,60)
	cool_light(a,r,Vector2(560,365),350,.48)
	a.lamp(r,810)

static func twin_halls(a, r) -> void:
	# Two bays with two broad openings, not a single bottleneck. Straight wall pieces are north-facing.
	a.Variants.cut_corner(r.field,"nw",330,262)
	a.Variants.cut_corner(r.field,"se",1130,735)
	a.Shell.wall(r.field,"twin_partition_north",Rect2(704,128,32,190),"top")
	# A freestanding screen belongs to actor depth sorting, not the exterior wall layer.
	low_wall(a,r,"twin_partition_middle",720,640,250)
	low_wall(a,r,"front_bay",425,630,250)
	prop(a,r,"front_table","bench",404,650,112,30)
	decal(a,r,"front_records","papers",470,677,88)
	kit(a,r,"back_tablet","tablet",1090,265,140,false)
	kit(a,r,"back_plinth","plinth",1100,656,70)
	kit(a,r,"back_relic","relic_chest",1165,666,40)
	column(a,r,1040,475)
	prop(a,r,"bay_crates","covered_crates",355,310,85,38)
	a.lamp(r,485)
	cool_light(a,r,Vector2(1050,365),260,.33)

static func loading_bay(a, r) -> void:
	# Staggered stock islands leave north/south lanes and two transverse passages for carrying goods.
	a.Variants.cut_corner(r.field,"ne",1140,270)
	for spec in [[420,345,100],[705,360,110],[995,600,105],[680,655,95]]:
		prop(a,r,"stock_%d" % spec[0],"covered_crates",spec[0],spec[1],spec[2],44)
	for p in [Vector2(478,383),Vector2(750,410),Vector2(939,644)]:
		prop(a,r,"crate_%d" % p.x,"material-crate",p.x,p.y,58,34)
	prop(a,r,"receiving_pallet","metal-pallet",300,574,112,44).floor_mark = 2
	prop(a,r,"outgoing_pallet","metal-pallet",1120,345,105,40).floor_mark = 2
	prop(a,r,"inventory_desk","bench",475,195,120,28).wall_shadow = true
	decal(a,r,"inventory","papers",540,226,72)
	a.lamp(r,420)
	a.lamp(r,1010)

static func cistern(a, r) -> void:
	# Raised enclosed reservoir, not walkable water. Four sides remain accessible.
	r.field.theme.ambient = Color(.73,.81,.83)
	var reservoir = kit(a,r,"reservoir","cistern",560,465,290)
	# Art atlas interior: inset to protect stone rim and its contact shadow.
	reservoir.water_surface = Rect2(82.0/589,73.0/399,430.0/589,195.0/399)
	reservoir.water_sunlight = true
	for x in [355,765]:
		column(a,r,x,282)
		prop(a,r,"water_buttress_%d" % x,"buttress",x,152,54,18)
	prop(a,r,"supply_trough","quench_trough",330,604,110,35)
	a.flat(r,"damp_edge","moss_long",Vector2(565,492),285,.65)
	a.moss(r,Vector2(790,177),150)
	low_wall(a,r,"water_screen",825,606,180,true)
	kit(a,r,"water_record","tablet",821,234,66,false)
	cool_light(a,r,Vector2(560,335),260,.37)
	a.lamp(r,300)

static func guard_post(a, r) -> void:
	# Offset breastworks guard the east half. Broad north and south approaches flank them.
	a.Variants.cut_corner(r.field,"sw",280,580)
	low_wall(a,r,"breastwork_north",605,330,240,true)
	low_wall(a,r,"breastwork_south",750,540,220)
	column(a,r,710,325)
	column(a,r,650,535)
	prop(a,r,"guard_table","tea_table",827,224,65,26)
	prop(a,r,"guard_supplies","material-crate",885,266,60,34)
	a.flat(r,"guard_bed","bedroll",Vector2(835,650),80)
	decal(a,r,"dropped_watch_notes","papers",800,402,75)
	decal(a,r,"guard_trace","carapace",400,550,100)
	a.lamp(r,795)

static func fallen_gate(a, r) -> void:
	# Gate supports retain their original span; both leaves fell into the room, toward the south-east.
	for x in [420,700]:
		prop(a,r,"gate_buttress_%d" % x,"buttress",x,165,72,27)
		column(a,r,x,300)
	kit(a,r,"gate_leaves","fallen_gate",567,479,248)
	a.flat(r,"gate_impact","floor_crack",Vector2(575,466),245,.7)
	prop(a,r,"gate_block",a.COLLAPSE_KIT % "roof_collapse",735,553,130,55)
	low_wall(a,r,"gate_side",810,300,180,true)
	decal(a,r,"drag_trace","carapace",845,578,110,.8)
	a.lamp(r,340)
	cool_light(a,r,Vector2(615,285),230,.35)

static func vault(a, r) -> void:
	# Most display places are empty. The lone surviving coffer is off the direct travelling line.
	for x in [350,560,770]:
		kit(a,r,"display_%d" % x,"plinth",x,320,68)
		kit(a,r,"display_south_%d" % x,"plinth",x,590,68)
	low_wall(a,r,"display_recess",790,410,230)
	kit(a,r,"last_coffer","relic_chest",858,300,46)
	kit(a,r,"archive_shelf","archive_shelf",365,220,160,false).wall_shadow = true
	kit(a,r,"vault_preserved","sealed_storage",845,218,82)
	decal(a,r,"vault_catalog","records",423,356,64,.7)
	kit(a,r,"vault_wrappings","sealed_storage",862,602,92)
	a.lamp(r,750)
	cool_light(a,r,Vector2(365,470),170,.18)

static func chapel(a, r) -> void:
	# A north altar and short pews frame an unobstructed central approach.
	kit(a,r,"altar","altar",560,245,125)
	kit(a,r,"stele","tablet",560,167,92,false)
	for x in [370,750]:
		column(a,r,x,270)
		for y in [440,570]: kit(a,r,"prayer_stone_%d_%d" % [x,y],"plinth",x,y,84)
	a.flat(r,"aisle_rug","rug",Vector2(560,410),180,.5)
	# Side entrances reveal the sanctuary beyond two short screens; the central aisle stays open.
	low_wall(a,r,"sanctuary_west",353,350,220)
	low_wall(a,r,"sanctuary_east",767,350,220)
	decal(a,r,"offerings","records",582,287,62,.6)
	a.lamp(r,460)
	a.lamp(r,660)
	cool_light(a,r,Vector2(560,275),170,.2)

static func storage_cells(a, r) -> void:
	# Three side bays with staggered entrances; the main west/east route remains independent.
	for x in [490,900]:
		a.Shell.wall(r.field,"cell_divider_%d" % x,Rect2(x,128,32,260),"top")
	# Low frontage guides movement; camera framing, not wall occlusion, delays the coffer reveal.
	low_wall(a,r,"cell_front_west",305,405,290)
	low_wall(a,r,"cell_front_middle",787,405,250)
	kit(a,r,"cell_front_east","archive_shelf",1100,405,175,false)
	for x in [330,715,1090]:
		kit(a,r,"bay_shelf_%d" % x,"archive_shelf",x,220,160,false).wall_shadow = true
	kit(a,r,"cell_stock","sealed_storage",300,318,96)
	kit(a,r,"cell_empty_display","plinth",755,280,72)
	kit(a,r,"cell_hidden_coffer","relic_chest",1190,210,66)
	a.Variants.cut_corner(r.field,"sw",350,650)
	a.Variants.cut_corner(r.field,"se",1090,650)
	decal(a,r,"cell_packing","records",1020,458,62)
	a.lamp(r,335)
	a.lamp(r,1090)

static func beast_nest(a, r) -> void:
	# Stolen belongings form a trail from the south-west to a sheltered north-east nest.
	a.Variants.cut_corner(r.field,"nw",285,250)
	low_wall(a,r,"nest_shelter",744,255,270,true)
	decal(a,r,"nest_soil","soil_roots",742,367,290,.9)
	kit(a,r,"nest","nest",742,438,170)
	a.raised(r,"nest_root",KIT % "floor_root",Vector2(808,427),170,.38,true,[-5.0,5.0])
	prop(a,r,"stolen_crate","material-crate",598,470,54,30)
	a.flat(r,"stolen_bed","bedroll",Vector2(476,529),73,.8,true)
	decal(a,r,"shed_shell","carapace",382,586,120)
	decal(a,r,"stolen_notes","papers",510,502,80)
	column(a,r,470,250)
	a.moss(r,Vector2(910,193),130)
	cool_light(a,r,Vector2(757,335),200,.23)
	a.lamp(r,360)

static func archive(a, r) -> void:
	# Record tablets face the reader, with one buried corner and an accessible reading table.
	a.Variants.cut_corner(r.field,"ne",880,265)
	for x in [310,530,750]: kit(a,r,"record_%d" % x,"tablet",x,220,106,false)
	kit(a,r,"reading_table","reading_desk",423,431,160)
	decal(a,r,"fallen_pages","records",448,473,64)
	kit(a,r,"record_base","plinth",740,515,80)
	prop(a,r,"buried_beam",a.COLLAPSE_KIT % "roof_collapse",811,639,170,65)
	a.flat(r,"buried_crack","floor_crack",Vector2(802,654),190,.65)
	kit(a,r,"fallen_record","tablet",870,570,77,false)
	kit(a,r,"archive_record_stand","plinth",286,603,75)
	a.lamp(r,410)
	cool_light(a,r,Vector2(790,535),230,.33)

static func repair_room(a, r) -> void:
	# Timber shoring sits beneath damaged stone, with tools on the working side and bedding on the other.
	a.Variants.cut_corner(r.field,"se",870,598)
	low_wall(a,r,"repaired_wall",493,280,290)
	kit(a,r,"shoring","shoring",485,294,108,false)
	prop(a,r,"repair_bench","bench",379,441,120,30)
	decal(a,r,"repair_tools","papers",434,480,100)
	prop(a,r,"repair_stock","metal-pallet",306,537,83,34)
	prop(a,r,"repair_crate","material-crate",760,308,63,35)
	a.flat(r,"repair_bed","bedroll",Vector2(720,552),78)
	prop(a,r,"repair_tea","tea_table",797,530,57,24)
	prop(a,r,"repair_rubble","rubble_small",585,286,64,20)
	a.lamp(r,480)
	a.glow(r,Vector2(718,501),150,.10)

static func secret_room(a, r) -> void:
	# The north alcove is outside BOTH arrival cameras. A low screen guides a dog-leg approach;
	# concealment comes from camera framing, never from pretending the low wall blocks sight.
	a.Variants.cut_corner(r.field,"sw",345,650)
	a.Variants.cut_corner(r.field,"nw",780,350)
	low_wall(a,r,"secret_screen",1075,390,320)
	column(a,r,1210,377)
	kit(a,r,"alcove_side","archive_shelf",1230,250,100,false)
	kit(a,r,"secret_coffer","relic_chest",1138,210,70)
	kit(a,r,"empty_hint","plinth",830,410,64)
	decal(a,r,"trail_note","records",850,495,62,.65)
	a.moss(r,Vector2(1260,160),50)
	a.lamp(r,950)
	cool_light(a,r,Vector2(1128,238),105,.25)

# Existing masonry sampled at the same world-space period as ConnectedWallSurface.
# These shallow interior faces are entirely inside the blocked shaft and shade into depth.
static func shaft_face(a, r, target: Rect2, shade: float) -> void:
	var texture: Texture2D = r.field.theme.wall_face
	var period := Vector2(r.field.theme.face_repeat,r.field.theme.face_repeat_y)
	var start := (target.position/period).floor()
	var finish := (target.end/period).ceil()
	for x in range(int(start.x),int(finish.x)):
		for y in range(int(start.y),int(finish.y)):
			var origin := Vector2(x,y)*period
			var patch := target.intersection(Rect2(origin,period))
			var atlas := AtlasTexture.new()
			atlas.atlas = texture
			atlas.region = Rect2((patch.position-origin)/period*texture.get_size(),patch.size/period*texture.get_size())
			atlas.filter_clip = true
			var p = a.Placement.new()
			p.placement_id = "authored_shaft_face_%d" % r.field.placements.size()
			p.position = patch.position
			p.visual_rect = Rect2(Vector2.ZERO,patch.size)
			p.texture = atlas
			p.floor_decal = true
			p.tint = Color(.66,.64,.60,clampf(shade/.76,0,1))
			r.field.placements.append(p)

static func overlook(a, r) -> void:
	# A lined shaft viewed downward, framed by masonry continuous with the north wall.
	# The background ends UNDER the structural sides and the front parapet, never against bare floor.
	a.flat(r,"distant_depth","res://assets/stages/ashen-foundry-v2/exploration-kit/overlook-depth-v3.png",Vector2(720,328),800,1)
	a.block(r,"view_void",Rect2(320,128,800,400))
	for strip in range(12):
		var fade: float = pow(1.0-float(strip)/12.0,1.5)*.72+.04
		shaft_face(a,r,Rect2(320,128+strip*8,800,8),fade)
		shaft_face(a,r,Rect2(320+strip*4,128,4,400),fade*.8)
		shaft_face(a,r,Rect2(1116-strip*4,128,4,400),fade*.8)
		shaft_face(a,r,Rect2(320,488-strip*4,800,4),fade*.7)

	a.Shell.wall(r.field,"view_reveal_west",Rect2(288,80,32,480),"top")
	a.Shell.wall(r.field,"view_reveal_east",Rect2(1120,80,32,480),"top")
	# This is the inaccessible pit boundary, continuous with the side walls, not a freestanding prop.
	# Reuse the room masonry at its native repeating scale instead of introducing a different rail material.
	a.Shell.wall(r.field,"view_front_lip",Rect2(288,528,864,32),"face")
	# One existing root crosses the near corner, connecting the room floor and the opening visually.
	var root = a.put(r,"view_corner_root",KIT % "floor_root",Vector2(370,572),205,18)
	root.wall_shadow = true
	root.tint = Color(.8,.82,.77)
	kit(a,r,"view_bench","seat",545,690,132)
	kit(a,r,"view_bench_east","seat",935,690,132)
	decal(a,r,"traveler_map","records",622,724,48)
	kit(a,r,"view_marker","tablet",1210,635,80,false)
	a.Variants.cut_corner(r.field,"sw",310,720)
	a.Variants.cut_corner(r.field,"se",1130,720)
	cool_light(a,r,Vector2(720,590),270,.18)
	a.lamp(r,245)

static func antechamber(a, r) -> void:
	# Central approach leads to a monumental sealed door; preview circulation remains west-east.
	for x in [395,725]:
		prop(a,r,"threshold_buttress_%d" % x,"buttress",x,152,66,24)
		column(a,r,x,310)
	# Wall-mounted sealed gate: art only, never advertised as a connected exit.
	var open_gateway: bool = r.doors.any(func(d): return d.id == "north")
	if not open_gateway:
		var gate = kit(a,r,"sealed_gate","sealed_gate",560,205,160,false)
		gate.wall_shadow = true
		gate.collision = Rect2(-80,-77,160,77)
	# These are architectural supports; the north opening remains completely walkable.
	for x in [455,665]:
		prop(a,r,"gate_jamb_%d" % x,"pillar",x,205,60,77).wall_shadow = true
	decal(a,r,"fresh_shell","carapace",605,365,165)
	decal(a,r,"outer_shell","carapace",715,507,95,.68).flip_h = true
	a.flat(r,"claw_fracture","floor_crack",Vector2(566,263),145,.75)
	prop(a,r,"crushed_crate","rubble_small",395,543,65,22)
	prop(a,r,"left_supplies","material-crate",324,584,56,30)
	a.flat(r,"left_bed","bedroll",Vector2(390,620),75,.78)
	a.lamp(r,315)
	a.lamp(r,805)
	r.field.theme.ambient = Color(.72,.74,.77)
