extends SceneTree
# Wall features without their own masonry (authored-room review 4, 2026-09-27). The generated wall breach and
# roots-through-the-wall pictures include surrounding stones at a different size and joint layout than the real
# wall, so laid over the wall they read as pasted patches. This keeps only the feature so the real wall shows:
# - part below the wall line (spilled blocks, root feet on the floor): kept whole;
# - above it: the dark hole (breach) or the brown roots (roots), plus a few px of their ink outline.
# Input/output: assets/stages/ashen-foundry-v2/props/<id>.png -> <id>_core.png (inputs are not modified).
# Run: Godot --headless --path . --script res://tools/build_wall_feature_cores.gd --quit-after 300
const DIR := "res://assets/stages/ashen-foundry-v2/props/"
# Share of the picture height taken by the wall (cap top y 44 to floor line y 128) at the widths used in rooms.
const WALL_SHARE := {"wall_breach":84.0/131.0,"wall_roots":84.0/113.0}
const OUTLINE_PX := 3
const OPEN_PX := 3
# Smallest kept shape above the wall line, in pixels per 10,000 picture pixels.
const MIN_SHAPE := 60

static func keep_above(id: String, c: Color) -> bool:
	if id == "wall_breach": return c.v < .16 and c.a > .5 # the dark hole
	# Brown roots: warmer and more saturated than the grey-brown stone.
	var hue := c.h*360.0
	return c.a > .5 and c.s > .34 and hue > 12 and hue < 48 and c.v > .12

func _initialize() -> void:
	for id in WALL_SHARE:
		var src := Image.load_from_file(ProjectSettings.globalize_path(DIR+id+".png"))
		src.convert(Image.FORMAT_RGBA8)
		var w := src.get_width()
		var h := src.get_height()
		# The drawn wall runs edge to edge: its floor line is the lowest row still opaque at the picture edges.
		var line := int(h*float(WALL_SHARE[id]))
		for y in range(h-1,-1,-1):
			if src.get_pixel(14,y).a > .5 and src.get_pixel(w-15,y).a > .5:
				line = y+6 # a few px past the last course: its bottom edge runs slightly lower mid-width
				break
		var keep := PackedByteArray()
		keep.resize(w*h)
		for y in range(h):
			for x in range(w):
				if y >= line+4 or keep_above(id,src.get_pixel(x,y)): keep[y*w+x] = 1
		# Fallen stones in front of the wall's foot: stone interiors (split by ink joints) that reach below the
		# floor line are kept whole; the wall's own courses end above it and are dropped.
		var stone_seen := PackedByteArray()
		stone_seen.resize(w*h)
		for start in range(line*w,mini(h,line+2)*w):
			var c0 := src.get_pixel(start%w,start/w)
			if stone_seen[start] == 1 or c0.a < .5 or c0.v < .16: continue
			var stone := PackedInt32Array()
			var todo := [start]
			stone_seen[start] = 1
			while not todo.is_empty():
				var i: int = todo.pop_back()
				stone.append(i)
				for n in [i-1,i+1,i-w,i+w]:
					if n < 0 or n >= w*h or stone_seen[n] == 1 or absi(n%w-i%w) > 1: continue
					var c := src.get_pixel(n%w,n/w)
					if c.a < .5 or c.v < .16: continue
					stone_seen[n] = 1
					todo.append(n)
			# A stone spreading over most of the width is the wall itself, not a fallen block.
			var min_x := w
			var max_x := 0
			var max_y := 0
			for i in stone:
				min_x = mini(min_x,i%w)
				max_x = maxi(max_x,i%w)
				max_y = maxi(max_y,i/w)
			# Fallen blocks reach well past the floor line; a bottom-course brick only grazes it.
			if max_x-min_x < w*.4 and max_y >= line+8:
				for i in stone: keep[i] = 1
		# Opening (shrink then grow by OPEN_PX) above the wall line: the thin masonry joints that touch the hole
		# vanish, the hole itself survives.
		if id == "wall_breach":
			for step in range(2):
				for r in range(OPEN_PX):
					var next := keep.duplicate()
					for y in range(1,line-1):
						for x in range(1,w-1):
							var i := y*w+x
							var around: Array = [keep[i-1],keep[i+1],keep[i-w],keep[i+w]]
							if step == 0 and keep[i] == 1 and 0 in around: next[i] = 0
							if step == 1 and keep[i] == 0 and 1 in around and src.get_pixel(x,y).v < .16: next[i] = 1
					keep = next
		# Above the wall line keep only large connected shapes: masonry ink joints are as dark as the hole and
		# some joint pixels pass the root colour test, but they form thin separate lines.
		var seen := PackedByteArray()
		seen.resize(w*h)
		for start in range(w*line):
			if keep[start] != 1 or seen[start] == 1: continue
			var shape := PackedInt32Array()
			var pending := [start]
			seen[start] = 1
			while not pending.is_empty():
				var i: int = pending.pop_back()
				shape.append(i)
				for n in [i-1,i+1,i-w,i+w]:
					if n < 0 or n >= w*line or seen[n] == 1 or keep[n] != 1: continue
					if absi(n%w-i%w) > 1: continue
					seen[n] = 1
					pending.append(n)
			if shape.size() < MIN_SHAPE*w*h/10000:
				for i in shape: keep[i] = 0
		# Grow the kept area a little so the ink outline of the hole/roots stays.
		for pass_i in range(OUTLINE_PX):
			var grown := keep.duplicate()
			for y in range(1,h-1):
				for x in range(1,w-1):
					if keep[y*w+x] == 1: continue
					if keep[y*w+x-1] == 1 or keep[y*w+x+1] == 1 or keep[(y-1)*w+x] == 1 or keep[(y+1)*w+x] == 1:
						if src.get_pixel(x,y).v < .3: grown[y*w+x] = 1
			keep = grown
		var out := Image.create(w,h,false,Image.FORMAT_RGBA8)
		for y in range(h):
			for x in range(w):
				if keep[y*w+x] == 1: out.set_pixel(x,y,src.get_pixel(x,y))
		assert(out.save_png(ProjectSettings.globalize_path(DIR+id+"_core.png")) == OK)
		print(id," core saved")
	print("PASS: wall feature cores")
	quit()
