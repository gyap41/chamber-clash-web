extends SceneTree
# Measures opaque sprite bounds without modifying the generated source images.
func _initialize() -> void:
	var records := {}
	for tier in ["c","b","a","s"]:
		var path: String = "res://assets/sprites/chests/rarity-v2/"+tier+".png"
		var image := Image.load_from_file(path)
		assert(image.detect_alpha() != Image.ALPHA_NONE)
		var cell := image.get_size()/2
		var regions: Array = []
		for frame in range(4):
			var origin := Vector2i(frame%2,frame/2)*cell
			var low := origin+cell
			var high := origin
			for y in range(origin.y,origin.y+cell.y):
				for x in range(origin.x,origin.x+cell.x):
					if image.get_pixel(x,y).a > .5:
						low = low.min(Vector2i(x,y))
						high = high.max(Vector2i(x,y))
			var region := Rect2i(low-Vector2i(3,3),high-low+Vector2i(7,7)).intersection(Rect2i(origin,cell))
			regions.append([region.position.x,region.position.y,region.size.x,region.size.y])
		records[tier] = {"file":path,"sha256":FileAccess.get_sha256(path),"regions":regions,"provider":"built-in imagegen","prompt":tier+"-prompt.txt","alpha_threshold":.5,"padding":3}
	var file := FileAccess.open("res://assets/sprites/chests/rarity-v2/manifest.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(records,"\t"))
	print(records)
	quit()
