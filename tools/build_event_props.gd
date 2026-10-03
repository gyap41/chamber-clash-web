extends SceneTree
# Builds the event-room props (docs/art/production/event-rooms) from the generated sheet
# assets/generated/event-props-v1.png, which is never modified. The sheet is a 3x3 grid on flat magenta:
# the magenta is keyed out with colour unmixing at soft edges, each cell is trimmed to its visible pixels
# (alpha >= .1, 2 px margin) and saved as an AtlasTexture. The teleporter glow is derived from the
# platform's own blue-green channels so it lines up exactly. Deterministic; rerun after changing the sheet.
# Run: Godot --headless --path . --script res://tools/build_event_props.gd --quit-after 600
const SOURCE := "res://assets/generated/event-props-v1.png"
const OUT := "res://assets/stages/ashen-foundry-v2/event-props/"
const KEY := Color(1,0,1)
const IDS := ["coin_small","coin_large","shop_stand","shop_sign","teleporter_base","teleporter_glow_drawn",
	"challenge_plinth","challenge_emblem_glow","altar_small"]

func _init() -> void:
	var source := Image.load_from_file(ProjectSettings.globalize_path(SOURCE))
	source.convert(Image.FORMAT_RGBA8)
	var keyed := key_out(source)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var sheet_path := OUT+"event-props-v1.png"
	assert(keyed.save_png(ProjectSettings.globalize_path(sheet_path)) == OK)
	var cell := source.get_width()/3
	var regions := {}
	for index in range(IDS.size()):
		var area := Rect2i((index%3)*cell,(index/3)*cell,cell,cell)
		var bounds := visible_bounds(keyed,area)
		assert(bounds.size.x > 8 and bounds.size.y > 8,"Empty cell "+IDS[index])
		# Most of the prop lies in its own cell.
		assert(area.intersection(bounds).get_area() > bounds.get_area()*.7,"Prop mostly outside its cell: "+IDS[index])
		regions[IDS[index]] = bounds
	# Derived glow: the platform's blue-green inlay as a white-cyan light mask at the platform's own region.
	var base: Rect2i = regions.teleporter_base
	var glow := Image.create(keyed.get_width(),keyed.get_height(),false,Image.FORMAT_RGBA8)
	for y in range(base.position.y,base.end.y):
		for x in range(base.position.x,base.end.x):
			var c := keyed.get_pixel(x,y)
			var teal := clampf((minf(c.g,c.b)-c.r-.12)*4.0,0,1)*c.a
			if teal > 0: glow.set_pixel(x,y,Color(.75,1,1,teal))
	var glow_path := OUT+"teleporter-glow-v1.png"
	assert(glow.save_png(ProjectSettings.globalize_path(glow_path)) == OK)
	var sheet := load_image_texture(sheet_path)
	var glow_texture := load_image_texture(glow_path)
	for id in IDS:
		save_atlas(sheet,regions[id],id)
	save_atlas(glow_texture,base,"teleporter_glow")
	var record := {"source":SOURCE,"source_sha256":FileAccess.get_sha256(SOURCE),"sheet":sheet_path,
		"key":"magenta #FF00FF, alpha from colour distance .25..0.6 with unmixing and magenta despill","threshold":"alpha >= 0.1, 2 px margin","regions":{}}
	for id in regions: record.regions[id] = [regions[id].position.x,regions[id].position.y,regions[id].size.x,regions[id].size.y]
	record.regions.teleporter_glow = record.regions.teleporter_base
	var file := FileAccess.open(OUT+"regions.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(record,"  "))
	file.close()
	print("PASS: event props extracted ",regions)
	quit()

# Alpha from the distance to the key colour; semi-transparent edges are unmixed from magenta so they keep
# their own colour instead of a pink fringe.
func key_out(image: Image) -> Image:
	var result := Image.create(image.get_width(),image.get_height(),false,Image.FORMAT_RGBA8)
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var c := image.get_pixel(x,y)
			var distance := Vector3(c.r-KEY.r,c.g-KEY.g,c.b-KEY.b).length()
			var alpha := clampf((distance-.25)/.35,0,1)
			if alpha <= 0: continue
			var unmixed := Color((c.r-(1-alpha)*KEY.r)/alpha,(c.g-(1-alpha)*KEY.g)/alpha,(c.b-(1-alpha)*KEY.b)/alpha,alpha)
			# Despill: no prop uses purple, so red and blue above green are key contamination (outline fringes).
			var spill := maxf(minf(unmixed.r,unmixed.b)-unmixed.g,0)
			result.set_pixel(x,y,Color(clampf(unmixed.r-spill,0,1),clampf(unmixed.g,0,1),clampf(unmixed.b-spill,0,1),alpha))
	return result

# Bounds of the connected shape (alpha >= .1) with the most pixels inside the cell. It may extend past the cell
# (the plinth's bell reaches into the row above), and a neighbour's overhanging part is not picked up.
func visible_bounds(image: Image, area: Rect2i) -> Rect2i:
	var width := image.get_width()
	var seen := PackedByteArray()
	seen.resize(width*image.get_height())
	var best := Rect2i()
	var best_count := 0
	for y in range(area.position.y,area.end.y,3):
		for x in range(area.position.x,area.end.x,3):
			if seen[y*width+x] or image.get_pixel(x,y).a < .1: continue
			var low := Vector2i(x,y)
			var high := Vector2i(x,y)
			var count := 0
			var stack: Array[Vector2i] = [Vector2i(x,y)]
			seen[y*width+x] = 1
			while not stack.is_empty():
				var p: Vector2i = stack.pop_back()
				if area.has_point(p): count += 1
				low = low.min(p)
				high = high.max(p)
				for offset in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
					var q: Vector2i = p+offset
					if q.x < 0 or q.y < 0 or q.x >= width or q.y >= image.get_height(): continue
					if seen[q.y*width+q.x] or image.get_pixel(q.x,q.y).a < .1: continue
					seen[q.y*width+q.x] = 1
					stack.append(q)
			if count > best_count:
				best_count = count
				best = Rect2i(low,high-low+Vector2i.ONE)
	return best.grow(2).intersection(Rect2i(Vector2i.ZERO,image.get_size()))

func load_image_texture(path: String) -> Texture2D:
	return ImageTexture.create_from_image(Image.load_from_file(ProjectSettings.globalize_path(path)))

func save_atlas(texture: Texture2D, region: Rect2i, id: String) -> void:
	# Atlas resources reference the imported PNG so the game loads them through the normal importer.
	var atlas := AtlasTexture.new()
	var path := OUT+("teleporter-glow-v1.png" if id == "teleporter_glow" else "event-props-v1.png")
	atlas.atlas = load(path) if ResourceLoader.exists(path) else texture
	atlas.region = Rect2(region)
	atlas.filter_clip = true
	assert(ResourceSaver.save(atlas,OUT+id+".tres") == OK)
