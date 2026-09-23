extends RefCounted
# Deterministic dressing; private placements never consume the floor layout RNG.
const THEME = preload("res://data/stage_themes/ashen_foundry.tres")
const ATLAS = preload("res://assets/stages/ashen-foundry/decals.png")
const ROOTS = preload("res://assets/stages/ashen-foundry/root-junctions-v2.png")
const ROOT_ENTRIES = preload("res://assets/stages/ashen-foundry/root-entries-v3.png")
const FURNISHINGS = preload("res://assets/stages/ashen-foundry/furnishings-v2.png")
static var sprite_cache: Dictionary = {}
const Placement = preload("res://scripts/world/stage_placement.gd")

static func apply(room, role: String, variation: int = 0) -> String:
	# Room resources can retain externally referenced fields after duplicate(true).
	# Explicitly own the field before assigning a story-only theme/placement list.
	room.field = room.field.duplicate(true)
	var field = room.field
	field.theme = THEME.duplicate(true)
	field.placements = field.placements.filter(func(prop): return not prop.placement_id.begins_with("ashen_"))
	var identity := "hearth" if role in ["start","treasure","shop"] else "overgrown" if role == "normal" and variation%3 == 1 else "foundry"
	if identity == "overgrown":
		field.theme.floor_tint = Color(.73,.79,.74)
		field.theme.wall_tint = Color(.75,.75,.66)
	for prop in field.placements:
		if prop.placement_id == "furnace": prop.tint = Color(.76,.74,.67)
	var area: Rect2 = field.floor_regions[0]
	if role == "boss":
		var bed = Placement.new()
		bed.placement_id = "ashen_casting_bed"
		bed.position = area.get_center()
		bed.visual_rect = Rect2(-320,-200,640,400)
		bed.floor_decal = true
		bed.floor_motif = 1
		field.placements.append(bed)
		for side in [-1,1]:
			decal(field,"bed_soot_"+str(side),1,area.get_center()+Vector2(side*290,110),Vector2(240,180))
			field.placements.back().tint = Color(1,1,1,.42)
	if identity == "overgrown":
		add_roots(room)
	elif identity == "foundry":
		decal(field,"ash_edge",1,area.position+Vector2(95,60),Vector2(180,110))
		if role in ["boss","antechamber"]:
			decal(field,"ash_east",1,Vector2(area.end.x-100,area.position.y+75),Vector2(210,135))
	if role in ["treasure","shop"]:
		decal(field,"rug",2,area.get_center(),Vector2(230,180))
	for prop in field.placements.duplicate():
		if prop.placement_id == "furnace":
			decal(field,"furnace_ash",1,prop.position+Vector2(0,60),Vector2(180,105))
		elif prop.placement_id == "bench":
			decal(field,"bench_offcuts",3,prop.position+Vector2(28,46),Vector2(95,75))
	if role != "boss":
		add_furnishings(room,role,variation)
	return identity

static func decal(field, id: String, cell: int, center: Vector2, size: Vector2) -> void:
	var prop = Placement.new()
	prop.placement_id = "ashen_"+id
	prop.position = center
	prop.visual_rect = Rect2(-size*.5,size)
	prop.floor_decal = true
	var texture := AtlasTexture.new()
	texture.atlas = ATLAS
	var cell_size := ATLAS.get_size()*.5
	texture.region = Rect2(Vector2(cell%2,cell/2)*cell_size,cell_size)
	texture.filter_clip = true
	prop.texture = texture
	field.placements.append(prop)

# Trim transparent atlas margins for reliable scale, foot sorting and contact shadows.
static func sprite(sheet: Texture2D, cell: int) -> AtlasTexture:
	var key := sheet.resource_path+str(cell)
	if sprite_cache.has(key): return sprite_cache[key]
	var size := Vector2i(sheet.get_size())/2
	var origin := Vector2i(cell%2,cell/2)*size
	var region: Rect2
	# Reviewed opaque bounds plus 2px fringe: nonzero-alpha dust reaches sheet edges.
	if sheet == FURNISHINGS:
		var crops := [Rect2(72,148,523,407),Rect2(31,223,561,322),Rect2(63,107,552,367),Rect2(76,128,467,350)]
		region = crops[cell]
		region.position += Vector2(origin)
	elif sheet == ROOT_ENTRIES:
		region = Rect2(107,25,439,633) if cell == 0 else Rect2(687,151,541,455)
	else:
		var used := sheet.get_image().get_region(Rect2i(origin,size)).get_used_rect()
		region = Rect2(Vector2(origin+used.position),Vector2(used.size))
	var texture := AtlasTexture.new()
	texture.atlas = sheet
	texture.region = region
	texture.filter_clip = true
	sprite_cache[key] = texture
	return texture

static func make_prop(id: String, sheet: Texture2D, cell: int, width: float):
	var prop = Placement.new()
	prop.placement_id = "ashen_"+id
	prop.texture = sprite(sheet,cell)
	var size := Vector2(width,width*prop.texture.get_height()/prop.texture.get_width())
	prop.visual_rect = Rect2(Vector2(-width*.5,-size.y),size)
	return prop

static func free_space(room, rect: Rect2, allow_wall: bool = false) -> bool:
	var field = room.field
	if not field.field_rect.encloses(rect): return false
	if not allow_wall:
		for corner in [rect.position,rect.end-Vector2.ONE,Vector2(rect.position.x,rect.end.y-1),Vector2(rect.end.x-1,rect.position.y)]:
			if not field.floor_contains(corner): return false
		for wall in field.walls:
			if wall.intersects(rect): return false
	for door in room.doors:
		var corridor := Rect2(door.position,Vector2.ZERO).expand(door.arrival).grow(56)
		if corridor.intersects(rect): return false
	for spawn in field.spawns:
		if rect.grow(40).has_point(spawn): return false
	for prop in field.placements:
		if prop.floor_decal: continue
		var occupied := Rect2(prop.position+prop.visual_rect.position,prop.visual_rect.size)
		if occupied.grow(10).intersects(rect): return false
	return true

static func add_furnishings(room, role: String, variation: int) -> void:
	var cells := [0,1]
	if role in ["start","treasure","shop"]: cells.append_array([2,3])
	for cell in cells:
		var widths := [140.0,112.0,96.0,72.0]
		var prop = make_prop(["mold_rack","quench_trough","covered_crates","tea_table"][cell],FURNISHINGS,cell,widths[cell])
		prop.shadow_rect = Rect2(-widths[cell]*.40,-8,widths[cell]*.80,7)
		prop.tint = Color(.88,.87,.81) if cell == 2 else Color(.91,.90,.86)
		if cell >= 2 and place_living_corner(room,prop,cell): continue
		var placed := false
		# Use actual north-facing wall segments, including the elbow's inset wall.
		for i in range(room.field.walls.size()):
			var wall: Rect2 = room.field.walls[i]
			if room.field.wall_materials.get(room.field.wall_ids[i],"") != "face" or wall.size.x < prop.visual_rect.size.x+48: continue
			var slots := maxi(1,int((wall.size.x-prop.visual_rect.size.x-32)/56)+1)
			for offset in range(slots):
				var slot: int = (offset+variation+cell)%slots
				prop.position = Vector2(wall.position.x+prop.visual_rect.size.x*.5+16+slot*56,wall.end.y+prop.visual_rect.size.y*(.55 if cell == 0 else 1.04))
				var visual := Rect2(prop.position+prop.visual_rect.position,prop.visual_rect.size)
				prop.collision = Rect2(-widths[cell]*.43,-prop.visual_rect.size.y*.4,widths[cell]*.86,prop.visual_rect.size.y*.38)
				var footprint := Rect2(prop.position+prop.collision.position,prop.collision.size)
				if not free_space(room,visual,true) or not free_space(room,footprint): continue
				prop.contact_shadow = true
				prop.wall_shadow = false
				room.field.placements.append(prop)
				placed = true
				break
			if placed: break

static func add_roots(room) -> void:
	var placed := {}
	for i in range(room.field.walls.size()):
		var wall: Rect2 = room.field.walls[i]
		var role: String = room.field.wall_materials.get(room.field.wall_ids[i],"")
		var cell := 0 if role == "face" and wall.size.x > 220 else 1 if role == "top" and wall.size.y > 220 and wall.position.x == 96 else -1
		if cell < 0 or placed.has(cell): continue
		var prop = make_prop("root_entry_"+str(cell),ROOT_ENTRIES,cell,120 if cell == 0 else 150)
		for ratio in [.25,.75,.5]:
			var top := Vector2(wall.position.x+wall.size.x*ratio-60,wall.end.y-42) if cell == 0 else Vector2(wall.end.x-28,wall.position.y+wall.size.y*ratio-55)
			prop.position = top-prop.visual_rect.position
			var visual := Rect2(top,prop.visual_rect.size)
			if not free_space(room,visual,true): continue
			prop.surface_overlay = true
			prop.tint = Color(.72,.72,.64)
			room.field.placements.append(prop)
			placed[cell] = true
			var moss = make_prop("moss_"+str(cell),ROOTS,2,110)
			moss.position = prop.position+Vector2(18,26)
			moss.floor_decal = true
			room.field.placements.append(moss)
			break
	# Shallow nests use alternative corners when the root entry occupies one.
	for region in room.field.floor_regions:
		if region.size.x < 250 or region.size.y < 200: continue
		for x in [region.position.x+65,region.end.x-65]:
			var nest = make_prop("nest",ROOTS,3,64)
			nest.position = Vector2(x,region.end.y-32)
			if not free_space(room,Rect2(nest.position+nest.visual_rect.position,nest.visual_rect.size)): continue
			nest.floor_decal = true
			room.field.placements.append(nest)
			return

static func place_living_corner(room, prop, cell: int) -> bool:
	# Shared corner anchors group storage and tea without filling the combat center.
	for region in room.field.floor_regions:
		if region.size.x < 300 or region.size.y < 250: continue
		for from_right in [true,false]:
			var inset := 74.0 if cell == 2 else 190.0
			prop.position = Vector2(region.end.x-inset if from_right else region.position.x+inset,region.end.y-22)
			var size: Vector2 = prop.visual_rect.size
			prop.collision = Rect2(-size.x*.43,-size.y*.4,size.x*.86,size.y*.38)
			if not free_space(room,Rect2(prop.position+prop.visual_rect.position,size)): continue
			prop.contact_shadow = true
			room.field.placements.append(prop)
			return true
	return false
