extends SceneTree
# Builds assets/first-workshop/enemies/lizard-sheet-v3.png from three generated sheets:
# lizard-v3-sheet-a.png (3x4: front/back/side x walk), -b.png (3x4: front/back/side x windup/spit/recover/
# defeated) and -c.png (4x4: rows 1-2 front, rows 3-4 back, 8 poses each in reading order). Sheet C replaced
# the thin front/back views of A and B after the design review, so only the side column of A and B is used.
# Magenta background -> transparent (edge fringe recoloured to the outline brown). Sprites are found as
# connected shapes (they do not stay inside the grid lines) and assigned to a cell by their centre.
# Each sprite is centred horizontally and its lowest point (planted feet) placed on GROUND.
# The generated side view faces LEFT; RIGHT is its mirror.
# Body greens are shifted from yellow-green toward a deeper, slightly darker green (still well above the floor) (design review
# 2026-09-26: the brightened body read as toy-like lime). Eyes, pouch and spikes are outside the hue range.
# Output: 4 columns (front, back, right, left) x 8 rows (walk 0-3, windup, spit, recover, defeated),
# plus a white silhouette of the same layout (lizard-sheet-v3-flash.png) for the hit flash.
# Originals are not modified. Run: Godot --headless --path . --script res://tools/build_lizard_v3_atlas.gd
const SOURCES := [
	{"path":"res://assets/generated/lizard-v3-sheet-a.png","cols":3,"rows":4,"first_pose":0},
	{"path":"res://assets/generated/lizard-v3-sheet-b.png","cols":3,"rows":4,"first_pose":4},
	# Sheet C was drawn duller and darker; its greens are matched to sheet A's measured averages
	# (A: hue 75, saturation .66, value .55; C: hue 78, saturation .52, value .50) before the common shift.
	{"path":"res://assets/generated/lizard-v3-sheet-c.png","cols":4,"rows":4,"first_pose":-1,
		"match":{"hue":-3.0,"saturation":1.27,"value":1.1}},
]
const OUT := "res://assets/first-workshop/enemies/lizard-sheet-v3.png"
const FLASH_OUT := "res://assets/first-workshop/enemies/lizard-sheet-v3-flash.png"
const GREEN_HUE := Vector2(65.0,150.0) # degrees
const HUE_SHIFT := 16.0
const GREEN_SATURATION := .85
const GREEN_VALUE := .9
const CELL := Vector2i(344,256)
const GROUND := 236
const SPRITE_MIN := 2000
const OUTLINE := Color(.2,.13,.08)

static func key(image: Image, match: Dictionary = {}) -> void:
	var hue_offset := float(match.get("hue",0.0))
	var saturation_gain := float(match.get("saturation",1.0))
	var value_gain := float(match.get("value",1.0))
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var c := image.get_pixel(x,y)
			# How magenta the pixel is: high red and blue, low green.
			var m := minf(c.r,c.b)-c.g
			if m > .45:
				image.set_pixel(x,y,Color(0,0,0,0))
			elif m > .12:
				image.set_pixel(x,y,Color(OUTLINE.r,OUTLINE.g,OUTLINE.b,1.0-(m-.12)/.33))
			elif c.s > .25 and c.h*360.0 > GREEN_HUE.x and c.h*360.0 < GREEN_HUE.y:
				image.set_pixel(x,y,Color.from_hsv(c.h+(hue_offset+HUE_SHIFT)/360.0,clampf(c.s*saturation_gain,0,1)*GREEN_SATURATION,
					clampf(c.v*value_gain,0,1)*GREEN_VALUE,c.a))

# Connected shapes of visible pixels (8-neighbour), largest first.
static func shapes(image: Image) -> Array:
	var w := image.get_width()
	var h := image.get_height()
	var label := PackedInt32Array()
	label.resize(w*h)
	label.fill(-1)
	var found: Array = []
	for start in range(w*h):
		if label[start] >= 0 or image.get_pixel(start%w,start/w).a <= .1: continue
		var id := found.size()
		var pixels := PackedInt32Array()
		var pending := [start]
		label[start] = id
		while not pending.is_empty():
			var i: int = pending.pop_back()
			pixels.append(i)
			var x := i%w
			var y := i/w
			for dy in [-1,0,1]:
				for dx in [-1,0,1]:
					var nx: int = x+dx
					var ny: int = y+dy
					if nx < 0 or ny < 0 or nx >= w or ny >= h: continue
					var n: int = ny*w+nx
					if label[n] < 0 and image.get_pixel(nx,ny).a > .1:
						label[n] = id
						pending.append(n)
		found.append(pixels)
	found.sort_custom(func(a, b): return a.size() > b.size())
	return found

# Atlas cells [column, row, mirrored] fed by one source cell.
static func targets(source: Dictionary, col: int, row: int) -> Array:
	if source.first_pose < 0: # sheet C: front (rows 0-1) / back (rows 2-3), 8 poses in reading order
		return [[0 if row < 2 else 1,(row%2)*4+col,false]]
	if col < 2: return [] # thin front/back views, replaced by sheet C
	return [[3,source.first_pose+row,false],[2,source.first_pose+row,true]] # side view faces left

static func box_of(pixels: PackedInt32Array, w: int) -> Rect2i:
	var min_p := Vector2i(1 << 30,1 << 30)
	var max_p := Vector2i(-1,-1)
	for i in pixels:
		min_p = Vector2i(mini(min_p.x,i%w),mini(min_p.y,i/w))
		max_p = Vector2i(maxi(max_p.x,i%w),maxi(max_p.y,i/w))
	return Rect2i(min_p,max_p-min_p+Vector2i.ONE)

func _initialize() -> void:
	var atlas := Image.create(CELL.x*4,CELL.y*8,false,Image.FORMAT_RGBA8)
	var report: Array = []
	var filled := {}
	for s in range(SOURCES.size()):
		var source: Dictionary = SOURCES[s]
		var src := Image.load_from_file(ProjectSettings.globalize_path(source.path))
		src.convert(Image.FORMAT_RGBA8)
		key(src,source.get("match",{}))
		var w := src.get_width()
		var cw: int = w/int(source.cols)
		var ch: int = src.get_height()/int(source.rows)
		var all := shapes(src)
		var sprites: Array = all.filter(func(p): return p.size() >= SPRITE_MIN)
		assert(sprites.size() == source.cols*source.rows,"%s: expected %d sprites, found %d" % [source.path,source.cols*source.rows,sprites.size()])
		var boxes: Array = sprites.map(func(p): return box_of(p,w))
		# Small detached bits (a spike tip, a claw) join the nearest sprite.
		var members: Array = sprites.map(func(p): return PackedInt32Array(p))
		for piece in all.filter(func(p): return p.size() < SPRITE_MIN):
			var centre := Vector2(box_of(piece,w).get_center())
			var nearest := 0
			for k in range(boxes.size()):
				if Rect2(boxes[k]).grow(2).has_point(centre) or Vector2(boxes[k].get_center()).distance_to(centre) < Vector2(boxes[nearest].get_center()).distance_to(centre):
					nearest = k
			if Rect2(boxes[nearest]).grow(6).has_point(centre): members[nearest].append_array(piece)
		for k in range(sprites.size()):
			var box: Rect2i = box_of(members[k],w)
			var centre := box.get_center()
			var col := clampi(centre.x/cw,0,source.cols-1)
			var row := clampi(centre.y/ch,0,source.rows-1)
			var piece := Image.create(box.size.x,box.size.y,false,Image.FORMAT_RGBA8)
			for i in members[k]:
				piece.set_pixel(i%w-box.position.x,i/w-box.position.y,src.get_pixel(i%w,i/w))
			assert(box.size.x <= CELL.x and box.size.y <= GROUND,"sprite larger than cell: %s" % box.size)
			for target in targets(source,col,row):
				var cell := Vector2i(target[0],target[1])
				assert(not filled.has(cell),"two sprites assigned to atlas column %d row %d" % [cell.x,cell.y])
				filled[cell] = true
				var placed: Image = piece.duplicate()
				if target[2]: placed.flip_x()
				var dest := Vector2i(cell.x*CELL.x+(CELL.x-box.size.x)/2,cell.y*CELL.y+GROUND-box.size.y)
				atlas.blend_rect(placed,Rect2i(Vector2i.ZERO,placed.get_size()),dest)
			report.append("sheet%d col%d row%d size=%s" % [s,col,row,box.size])
	assert(filled.size() == 32,"atlas cells filled: %d of 32" % filled.size())
	assert(atlas.save_png(ProjectSettings.globalize_path(OUT)) == OK)
	var flash := atlas.duplicate()
	for y in range(flash.get_height()):
		for x in range(flash.get_width()):
			flash.set_pixel(x,y,Color(1,1,1,atlas.get_pixel(x,y).a))
	assert(flash.save_png(ProjectSettings.globalize_path(FLASH_OUT)) == OK)
	report.sort()
	for line in report: print(line)
	print("PASS: lizard v3 atlas")
	quit()
