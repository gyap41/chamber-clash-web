extends SceneTree
# Cuts the ashen foundry v2 furniture, floor decorations and door pieces (docs/art/production/ashen-foundry-v2,
# stages 3-4) out of the generated sheets in assets/generated/ (never modified) into
# assets/stages/ashen-foundry-v2/props/<id>.png. Magenta -> transparent (edge fringe recoloured to the
# outline brown). Every connected shape is assigned to the grid cell containing its centre (a scatter such as
# the offcuts is several shapes); each cell must end up with enough pixels, specks are dropped.
# Run: Godot --headless --path . --script res://tools/build_stage_v2_props.gd --quit-after 600
const SHEETS := {
	"res://assets/generated/stage-v2-props-a.png":{"cols":3,"rows":2,"ids":["furnace","bench","cabinet","anvil","material-crate","metal-pallet"]},
	"res://assets/generated/stage-v2-props-b.png":{"cols":3,"rows":2,"ids":["lamp","pillar","mold_rack","quench_trough","covered_crates","tea_table"]},
	"res://assets/generated/stage-v2-decals-a.png":{"cols":3,"rows":2,"ids":["ash","rug","offcuts","moss","nest","root_down"]},
	"res://assets/generated/stage-v2-decals-b.png":{"cols":2,"rows":2,"ids":["root_side","threshold","barrier","ash_large"]},
}
const OUT := "res://assets/stages/ashen-foundry-v2/props/"
const SPRITE_MIN := 1500
const SPECK := 12
const MARGIN := 2
const OUTLINE := Color(.16,.11,.08)

static func key(image: Image) -> void:
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var c := image.get_pixel(x,y)
			var m := minf(c.r,c.b)-c.g # how magenta the pixel is
			if m > .45: image.set_pixel(x,y,Color(0,0,0,0))
			elif m > .12: image.set_pixel(x,y,Color(OUTLINE.r,OUTLINE.g,OUTLINE.b,1.0-(m-.12)/.33))

static func shapes(image: Image) -> Array:
	var w := image.get_width()
	var h := image.get_height()
	var label := PackedInt32Array()
	label.resize(w*h)
	label.fill(-1)
	var found: Array = []
	for start in range(w*h):
		if label[start] >= 0 or image.get_pixel(start%w,start/w).a <= .1: continue
		var pixels := PackedInt32Array()
		var pending := [start]
		label[start] = found.size()
		while not pending.is_empty():
			var i: int = pending.pop_back()
			pixels.append(i)
			for dy in [-1,0,1]:
				for dx in [-1,0,1]:
					var nx: int = i%w+dx
					var ny: int = i/w+dy
					if nx < 0 or ny < 0 or nx >= w or ny >= h: continue
					var n: int = ny*w+nx
					if label[n] < 0 and image.get_pixel(nx,ny).a > .1:
						label[n] = found.size()
						pending.append(n)
		found.append(pixels)
	return found

static func box_of(pixels: PackedInt32Array, w: int) -> Rect2i:
	var min_p := Vector2i(1 << 30,1 << 30)
	var max_p := Vector2i(-1,-1)
	for i in pixels:
		min_p = Vector2i(mini(min_p.x,i%w),mini(min_p.y,i/w))
		max_p = Vector2i(maxi(max_p.x,i%w),maxi(max_p.y,i/w))
	return Rect2i(min_p,max_p-min_p+Vector2i.ONE)

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	for path in SHEETS:
		var sheet: Dictionary = SHEETS[path]
		var cols: int = sheet.cols
		var rows: int = sheet.rows
		var src := Image.load_from_file(ProjectSettings.globalize_path(path))
		src.convert(Image.FORMAT_RGBA8)
		key(src)
		var w := src.get_width()
		var cw := w/cols
		var ch := src.get_height()/rows
		var cells: Array = []
		for i in range(cols*rows): cells.append(PackedInt32Array())
		for piece in shapes(src):
			if piece.size() < SPECK: continue
			var centre := box_of(piece,w).get_center()
			cells[clampi(centre.y/ch,0,rows-1)*cols+clampi(centre.x/cw,0,cols-1)].append_array(piece)
		for cell in range(cells.size()):
			var members: PackedInt32Array = cells[cell]
			assert(members.size() >= SPRITE_MIN,"%s: cell %d is empty" % [path,cell])
			var box := box_of(members,w)
			var out := Image.create(box.size.x+MARGIN*2,box.size.y+MARGIN*2,false,Image.FORMAT_RGBA8)
			for i in members:
				out.set_pixel(i%w-box.position.x+MARGIN,i/w-box.position.y+MARGIN,src.get_pixel(i%w,i/w))
			assert(out.save_png(ProjectSettings.globalize_path(OUT+sheet.ids[cell]+".png")) == OK)
			print("%s %s" % [sheet.ids[cell],box.size])
	print("PASS: stage v2 props")
	quit()
