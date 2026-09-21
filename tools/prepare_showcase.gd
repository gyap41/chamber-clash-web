extends SceneTree
# Deterministic atlas extraction and connected white-background removal. No API calls.
const DEST := "res://assets/first-workshop/showcase/"
func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(DEST)
	var source := Image.load_from_file("res://assets/generated/fw-showcase-surfaces-v1.png")
	if source == null: quit(1); return
	for i in range(4):
		var cell := source.get_region(Rect2i((i%2)*512,(i/2)*512,512,512))
		assert(cell.save_png(DEST+["floor","wall-face","wall-top","corner"][i]+".png") == OK)
	source = Image.load_from_file("res://assets/generated/fw-showcase-props-v1.png")
	if source == null: quit(1); return
	var records: Array = []
	for i in range(4):
		var cell := source.get_region(Rect2i((i%2)*512,(i/2)*512,512,512))
		cell.convert(Image.FORMAT_RGBA8)
		var visited := PackedByteArray()
		visited.resize(512*512)
		var queue: Array[Vector2i] = []
		for n in range(512):
			queue.append(Vector2i(n,0)); queue.append(Vector2i(n,511))
			queue.append(Vector2i(0,n)); queue.append(Vector2i(511,n))
		var head := 0
		while head < queue.size():
			var p := queue[head]
			head += 1
			if p.x < 0 or p.y < 0 or p.x >= 512 or p.y >= 512: continue
			var index := p.y*512+p.x
			if visited[index]: continue
			visited[index] = 1
			var c := cell.get_pixelv(p)
			if minf(c.r,minf(c.g,c.b)) < .91: continue
			cell.set_pixelv(p,Color(0,0,0,0))
			for offset in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]: queue.append(p+offset)
		# The bench slightly crosses the atlas divider; exclude its disconnected tip.
		if i == 0:
			for x in range(480,512):
				for y in range(512): cell.set_pixel(x,y,Color(0,0,0,0))
		# The lantern bracket encloses white background that cannot reach a cell edge.
		if i == 3:
			for x in range(512):
				for y in range(512):
					var c := cell.get_pixel(x,y)
					if minf(c.r,minf(c.g,c.b)) >= .91: cell.set_pixel(x,y,Color(0,0,0,0))
		var bounds := cell.get_used_rect()
		assert(bounds.has_area())
		var name: String = ["furnace","workbench","cabinet","lamp"][i]
		assert(cell.get_region(bounds).save_png(DEST+name+".png") == OK)
		records.append({"id":name,"source_cell":i,"crop":[bounds.position.x,bounds.position.y,bounds.size.x,bounds.size.y]})
	var file := FileAccess.open(DEST+"manifest.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"sources":["fw-showcase-surfaces-v1.png","fw-showcase-props-v1.png"],"grid":[2,2],"white_removal":"border-connected RGB minimum >= 0.91; lantern enclosed whites also removed; furnace cell x>=480 excluded as neighboring bench tip","props":records},"\t"))
	print("PASS: showcase material extraction")
	quit()
