extends SceneTree
# Style comparison sheet (docs/art/VISUAL_STYLE_GUIDE.md): current actors, props, walls and
# floor rendered together at the normal exploration camera, plus grayscale / blur /
# silhouette checks and per-element measurements. Each shot is repeated with the trial
# enemy correction (actor_readability.gdshader on a CanvasGroup). Does not modify game assets.
const OUT := "res://docs/art/reviews/style-comparison-2026-09-26/"
const Encounter = preload("res://scripts/game/exploration_encounter.gd")
const ROOM := "pillared"
# Two shots with the same camera: regular enemies around Rina, then the boss alone,
# because the boss sprite is too tall to share the frame with the enemy row.
const SHOTS := [
	{"name":"lineup","rina":Vector2(696,610),"actors":[
		{"id":"sentry","label":"番機","pos":Vector2(575,600)},
		{"id":"lizard","label":"火袋トカゲ","pos":Vector2(817,600)},
		{"id":"quillback","label":"棘背ヤマアラシ","pos":Vector2(975,560)},
	]},
	{"name":"boss","rina":Vector2(830,690),"actors":[
		{"id":"boss","label":"独楽の鋳造機","pos":Vector2(696,560)},
	]},
]
# Trial tone settings per enemy (gamma < 1 lifts dark values). Rina stays as the reference.
const CORRECTIONS := {
	"sentry":{"gamma":.7,"contrast":1.1,"brightness":.04,"saturation":1.12},
	"lizard":{"gamma":.8,"contrast":1.2,"brightness":.02,"saturation":.95},
	"quillback":{"gamma":1.0,"contrast":1.0,"brightness":0.0,"saturation":1.0},
	"boss":{"gamma":.5,"contrast":1.2,"brightness":.04,"saturation":1.3},
}
const OUTLINE_PX := 2.0
const OUTLINE_DARKEN := .35
const DIFF_THRESHOLD := .06
var game
var w := 0
var h := 0

func _initialize() -> void:
	call_deferred("run")

func grab() -> Image:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	image.convert(Image.FORMAT_RGBA8)
	return image

func spawn(id: String, pos: Vector2, corrected: bool) -> Node:
	var actor = Encounter.ActorScene.instantiate()
	var script: Script = Encounter.Actor
	if id == "lizard": script = Encounter.Lizard
	elif id == "quillback": script = Encounter.Quillback
	elif id == "boss": script = Encounter.Boss
	actor.set_script(script)
	actor.name = "Style_"+id
	var holder: Node = actor
	if corrected:
		var group := CanvasGroup.new()
		group.fit_margin = OUTLINE_PX*2+2
		group.clear_margin = OUTLINE_PX*2+2
		var material := ShaderMaterial.new()
		material.shader = preload("res://assets/shaders/actor_readability.gdshader")
		for key in CORRECTIONS[id]: material.set_shader_parameter(key,CORRECTIONS[id][key])
		material.set_shader_parameter("outline_px",OUTLINE_PX)
		material.set_shader_parameter("outline_darken",OUTLINE_DARKEN)
		group.material = material
		group.add_child(actor)
		holder = group
	game.arena.get_node("Players").add_child(holder)
	actor.prepare(pos)
	actor.state.angle = PI/2
	actor.sync_visual()
	return holder

func show_layers(players: bool, props: bool, walls: bool) -> void:
	game.arena.get_node("Players").visible = players
	for layer in ["StageBackground","StageForeground"]:
		if game.arena.has_node(layer): game.arena.get_node(layer).visible = props
	game.arena.get_node("Walls").visible = walls
	if game.arena.has_node("ConnectedWallSurface"): game.arena.get_node("ConnectedWallSurface").visible = walls

func to_screen(world: Vector2) -> Vector2:
	return game.arena.get_global_transform_with_canvas()*world

static func luma(c: Color) -> float:
	return (.2126*c.r+.7152*c.g+.0722*c.b)*100.0

# Pixels that differ between two renders. Pure darkening of the lower layer (a cast
# shadow) is marked 2 so colour statistics can skip it.
func diff_mask(top: Image, bottom: Image) -> PackedByteArray:
	var mask := PackedByteArray()
	mask.resize(w*h)
	for y in range(h):
		for x in range(w):
			var a: Color = top.get_pixel(x,y)
			var b: Color = bottom.get_pixel(x,y)
			var d: float = maxf(absf(a.r-b.r),maxf(absf(a.g-b.g),absf(a.b-b.b)))
			if d < DIFF_THRESHOLD: continue
			var shadow := false
			if b.r > .04 and b.g > .04 and b.b > .04:
				var kr: float = a.r/b.r
				var kg: float = a.g/b.g
				var kb: float = a.b/b.b
				var k_mean: float = (kr+kg+kb)/3.0
				shadow = k_mean < .92 and maxf(kr,maxf(kg,kb))-minf(kr,minf(kg,kb)) < .08
			mask[y*w+x] = 2 if shadow else 1
	return mask

# The actor under a screen point: the nearest shape of at least MIN_SHAPE pixels, so faint glows or
# antialiasing specks next to the feet are not picked as the actor.
const MIN_SHAPE := 150
func component(mask: PackedByteArray, seed: Vector2, radius: int) -> PackedInt32Array:
	var candidates: Array = []
	for y in range(maxi(0,int(seed.y)-radius),mini(h,int(seed.y)+radius)):
		for x in range(maxi(0,int(seed.x)-radius),mini(w,int(seed.x)+radius)):
			if mask[y*w+x] == 1: candidates.append([seed.distance_squared_to(Vector2(x,y)),y*w+x])
	candidates.sort_custom(func(a, b): return a[0] < b[0])
	var tried := {}
	var found := PackedInt32Array()
	for candidate in candidates:
		if tried.has(candidate[1]): continue
		found = flood(mask,candidate[1])
		if radius <= 1 or found.size() >= MIN_SHAPE: return found
		for i in found: tried[i] = true
	return found

func flood(mask: PackedByteArray, start: int) -> PackedInt32Array:
	var found := PackedInt32Array()
	var seen := {start:true}
	var pending := [start]
	var cursor := 0
	while cursor < pending.size():
		var index: int = pending[cursor]
		cursor += 1
		found.append(index)
		var x := index%w
		var y := index/w
		for dy in [-1,0,1]:
			for dx in [-1,0,1]:
				var nx: int = x+dx
				var ny: int = y+dy
				if nx < 0 or ny < 0 or nx >= w or ny >= h: continue
				var next: int = ny*w+nx
				# Bridge small gaps (thin outlines, antialiasing, cast shadows).
				if mask[next] != 0 and not seen.has(next):
					seen[next] = true
					pending.append(next)
	return found

func measure(label: String, pixels: PackedInt32Array, mask: PackedByteArray, top: Image, bottom: Image, blur_top: Image = null, blur_bottom: Image = null) -> Dictionary:
	var inside := {}
	for index in pixels:
		if mask[index] == 1: inside[index] = true
	var min_p := Vector2i(w,h)
	var max_p := Vector2i(-1,-1)
	var l_sum := 0.0
	var l_sq := 0.0
	var s_sum := 0.0
	var grad_sum := 0.0
	var grad_n := 0
	var edge_sum := 0.0
	var edge_n := 0
	for index in inside:
		var x: int = index%w
		var y: int = index/w
		min_p = Vector2i(mini(min_p.x,x),mini(min_p.y,y))
		max_p = Vector2i(maxi(max_p.x,x),maxi(max_p.y,y))
		var c: Color = top.get_pixel(x,y)
		var l := luma(c)
		l_sum += l
		l_sq += l*l
		s_sum += c.s
		var interior := x > 0 and y > 0 and x < w-1 and y < h-1
		if interior:
			for n in [index-1,index+1,index-w,index+w]:
				if not inside.has(n): interior = false
		if interior:
			grad_sum += (absf(luma(top.get_pixel(x+1,y))-luma(top.get_pixel(x-1,y)))+absf(luma(top.get_pixel(x,y+1))-luma(top.get_pixel(x,y-1))))*.25
			grad_n += 1
		else:
			edge_sum += absf(l-luma(bottom.get_pixel(x,y)))
			edge_n += 1
	var n: int = inside.size()
	if n == 0: return {"label":label,"pixels":0}
	var mean: float = l_sum/n
	# At-a-glance contrast: how much the element changes the 1/8 blurred screen over its box.
	var glance := 0.0
	if blur_top != null:
		for y in range(min_p.y,max_p.y+1):
			for x in range(min_p.x,max_p.x+1):
				glance += absf(luma(blur_top.get_pixel(x,y))-luma(blur_bottom.get_pixel(x,y)))
		glance /= float((max_p.x-min_p.x+1)*(max_p.y-min_p.y+1))
	return {
		"glance_contrast":snappedf(glance,.1),
		"label":label,
		"pixels":n,
		"width":max_p.x-min_p.x+1,
		"height":max_p.y-min_p.y+1,
		"luma_mean":snappedf(mean,.1),
		"luma_std":snappedf(sqrt(maxf(0.0,l_sq/n-mean*mean)),.1),
		"saturation_mean":snappedf(s_sum/n*100.0,.1),
		"detail":snappedf(grad_sum/maxi(1,grad_n),.01),
		"edge_contrast":snappedf(edge_sum/maxi(1,edge_n),.1),
		"bbox":[min_p.x,min_p.y,max_p.x-min_p.x+1,max_p.y-min_p.y+1],
	}

func measure_rect(label: String, image: Image, rect: Rect2i) -> Dictionary:
	var pixels := PackedInt32Array()
	var mask := PackedByteArray()
	mask.resize(w*h)
	for y in range(rect.position.y,rect.end.y):
		for x in range(rect.position.x,rect.end.x):
			pixels.append(y*w+x)
			mask[y*w+x] = 1
	var result := measure(label,pixels,mask,image,image)
	result.erase("edge_contrast")
	return result

# Largest separate pieces of a layer (walls or props); small fragments are ignored.
func pieces(mask: PackedByteArray, min_pixels: int) -> Array:
	var remaining := mask.duplicate()
	var found: Array = []
	for index in range(w*h):
		if remaining[index] != 1: continue
		var piece := component(remaining,Vector2(index%w,index/w),1)
		for p in piece: remaining[p] = 0
		if piece.size() >= min_pixels: found.append(piece)
	found.sort_custom(func(a, b): return a.size() > b.size())
	return found

func grayscale(image: Image) -> Image:
	var out: Image = image.duplicate()
	for y in range(h):
		for x in range(w):
			var l := luma(image.get_pixel(x,y))/100.0
			out.set_pixel(x,y,Color(l,l,l))
	return out

func blurred(image: Image) -> Image:
	var out: Image = image.duplicate()
	out.resize(w/8,h/8,Image.INTERPOLATE_BILINEAR)
	out.resize(w,h,Image.INTERPOLATE_BILINEAR)
	return out

func silhouette(actors: PackedByteArray, props: PackedByteArray, walls: PackedByteArray) -> Image:
	var out := Image.create(w,h,false,Image.FORMAT_RGBA8)
	for index in range(w*h):
		var c := Color(.93,.93,.93)
		if walls[index] == 1: c = Color(.55,.55,.55)
		if props[index] == 1: c = Color(.7,.7,.7)
		if actors[index] == 1: c = Color(.08,.08,.08)
		out.set_pixel(index%w,index/w,c)
	return out

func sheet(images: Array) -> Image:
	var out := Image.create(w,h,false,Image.FORMAT_RGBA8)
	for i in range(images.size()):
		var half: Image = images[i].duplicate()
		half.resize(w/2,h/2,Image.INTERPOLATE_BILINEAR)
		out.blit_rect(half,Rect2i(0,0,w/2,h/2),Vector2i((i%2)*w/2,(i/2)*h/2))
	return out

# Every measured actor cropped at 1:1 and 3x (nearest) on one neutral strip.
func strip(image: Image, entries: Array) -> Image:
	var pad := 16
	var total_w := pad
	var tallest := 0
	for entry in entries:
		total_w += entry.bbox[2]*4+pad*2
		tallest = maxi(tallest,entry.bbox[3]*3)
	var out := Image.create(total_w,tallest+pad*2,false,Image.FORMAT_RGBA8)
	out.fill(Color(.5,.5,.5))
	var x := pad
	for entry in entries:
		var r := Rect2i(entry.bbox[0],entry.bbox[1],entry.bbox[2],entry.bbox[3])
		var crop: Image = image.get_region(r)
		out.blit_rect(crop,Rect2i(Vector2i.ZERO,r.size),Vector2i(x,pad+tallest-r.size.y))
		var big: Image = crop.duplicate()
		big.resize(r.size.x*3,r.size.y*3,Image.INTERPOLATE_NEAREST)
		out.blit_rect(big,Rect2i(Vector2i.ZERO,big.get_size()),Vector2i(x+r.size.x+pad,pad+tallest-big.get_height()))
		x += r.size.x*4+pad*2
	return out

func save(image: Image, name: String) -> void:
	assert(image.save_png(OUT+name) == OK)

func capture_shot(shot: Dictionary, metrics: Dictionary, environment: bool, corrected: bool) -> Dictionary:
	var suffix := "-corrected" if corrected else ""
	var bucket: Array = metrics.corrected if corrected else metrics.actors
	var rina = game.players[0]
	rina.state.pos = shot.rina
	rina.state.angle = PI/2
	rina.sync_visual()
	# One idle animation tick so the 8-direction rig attaches its lower body.
	for i in range(6): rina.advance_visual(.05,false)
	# Measure the body; the held pistol is compared separately in the weapon audits.
	rina.get_node("Identity").hide()
	rina.get_node("Weapon").hide()
	var spawned: Array = []
	for spec in shot.actors: spawned.append(spawn(spec.id,spec.pos,corrected))
	game.fit_field_camera()
	game.refresh_hud()
	game.get_node("HUD").visible = true
	save(await grab(),shot.name+suffix+"-in-game.png")
	game.get_node("HUD").visible = false
	var full: Image = await grab()
	show_layers(false,true,true)
	var no_actors: Image = await grab()
	show_layers(true,true,true)
	var blur := blurred(full)
	var blur_empty := blurred(no_actors)
	var gray := grayscale(full)
	var actor_mask := diff_mask(full,no_actors)
	var labeled: Array = [{"id":"rina","label":"リナ","pos":shot.rina}]
	labeled.append_array(shot.actors)
	var entries: Array = []
	for spec in labeled:
		var entry := measure(spec.label,component(actor_mask,to_screen(spec.pos),60),actor_mask,full,no_actors,blur,blur_empty)
		entry.id = spec.id
		entry.shot = shot.name
		if spec.id != "rina" or (shot.name == "lineup" and not corrected): bucket.append(entry)
		entries.append(entry)
	save(full,shot.name+suffix+".png")
	save(strip(full,entries.filter(func(e): return e.pixels > 0)),shot.name+suffix+"-strip.png")
	if environment:
		show_layers(false,false,true)
		var walls_floor: Image = await grab()
		show_layers(false,false,false)
		var floor_only: Image = await grab()
		show_layers(true,true,true)
		var prop_mask := diff_mask(no_actors,walls_floor)
		var wall_mask := diff_mask(walls_floor,floor_only)
		var blur_walls := blurred(walls_floor)
		var blur_floor := blurred(floor_only)
		var index := 0
		for piece in pieces(wall_mask,400).slice(0,6):
			index += 1
			metrics.walls.append(measure("壁%d" % index,piece,wall_mask,walls_floor,floor_only,blur_walls,blur_floor))
		index = 0
		for piece in pieces(prop_mask,150).slice(0,8):
			index += 1
			metrics.props.append(measure("家具%d" % index,piece,prop_mask,no_actors,walls_floor,blur_empty,blur_walls))
		var center := to_screen(shot.rina)
		metrics.floor = measure_rect("床",floor_only,Rect2i(int(center.x)-120,int(center.y)-150,240,120))
		save(gray,"grayscale.png")
		save(blur,"blur.png")
		var sil := silhouette(actor_mask,prop_mask,wall_mask)
		save(sil,"silhouette.png")
		save(sheet([full,gray,blur,sil]),"sheet.png")
	for holder in spawned:
		holder.get_parent().remove_child(holder)
		holder.free()
	return {"full":full,"gray":gray,"blur":blur}

func run() -> void:
	# Rina is compared in her current 8-direction rig, which the game only enables with --rina-run or V.
	preload("res://scripts/visuals/character_rig8.gd").enabled = true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	root.size = Vector2i(1120,800)
	root.content_scale_size = root.size
	w = root.size.x
	h = root.size.y
	game = load("res://scenes/game/workshop_variants_preview.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	game.start_room = ROOM
	game.start_exploration(1)
	game.set_physics_process(false)
	var metrics: Dictionary = {"room":ROOM,"viewport":[w,h],"camera_zoom":game.arena.get_node("CombatCamera").zoom.x,
		"corrections":CORRECTIONS,"outline_px":OUTLINE_PX,"outline_darken":OUTLINE_DARKEN,
		"actors":[],"corrected":[],"walls":[],"props":[],"floor":{}}
	for i in range(SHOTS.size()):
		var before: Dictionary = await capture_shot(SHOTS[i],metrics,i == 0,false)
		var after: Dictionary = await capture_shot(SHOTS[i],metrics,false,true)
		# Top: before / after. Bottom: grayscale before / after.
		save(sheet([before.full,after.full,before.gray,after.gray]),SHOTS[i].name+"-before-after.png")
	var file := FileAccess.open(OUT+"metrics.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(metrics,"  ",false))
	file.close()
	for entry in metrics.actors+metrics.corrected+metrics.walls+metrics.props+[metrics.floor]:
		print(JSON.stringify(entry))
	game.queue_free()
	await process_frame
	print("PASS: style comparison captured")
	quit()
