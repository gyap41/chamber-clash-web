extends SceneTree
# Local extraction only; preserve the generated original and log the recipe.
func _initialize() -> void:
	var image := Image.load_from_file("res://assets/generated/fw-workbench-overhead-v1.png")
	if image == null: quit(1); return
	image.convert(Image.FORMAT_RGBA8)
	var width := image.get_width()
	var height := image.get_height()
	var seen := PackedByteArray()
	seen.resize(width*height)
	var queue := PackedInt32Array()
	for x in range(width): queue.append(x); queue.append((height-1)*width+x)
	for y in range(height): queue.append(y*width); queue.append(y*width+width-1)
	var head := 0
	while head < queue.size():
		var index := queue[head]
		head += 1
		if seen[index]: continue
		seen[index] = 1
		var x := index%width
		var y := index/width
		var c := image.get_pixel(x,y)
		if minf(c.r,minf(c.g,c.b)) < .91: continue
		image.set_pixel(x,y,Color(0,0,0,0))
		if x > 0: queue.append(index-1)
		if x < width-1: queue.append(index+1)
		if y > 0: queue.append(index-width)
		if y < height-1: queue.append(index+width)
	var rect := image.get_used_rect()
	assert(rect.has_area())
	assert(image.get_region(rect).save_png("res://assets/first-workshop/showcase/workbench-overhead.png") == OK)
	var file := FileAccess.open("res://assets/first-workshop/showcase/workbench-overhead.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"source":"assets/generated/fw-workbench-overhead-v1.png","crop":[rect.position.x,rect.position.y,rect.size.x,rect.size.y],"alpha_recipe":"border-connected RGB min >= .91","resized":false},"\t"))
	print("PASS: overhead workbench extraction; size=",rect.size)
	quit()
