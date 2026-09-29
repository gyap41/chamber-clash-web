extends SceneTree
# Preserve generated originals; the rail atlas only excludes transparent export padding.
const ROOT := "res://assets/stages/ashen-foundry-v2/exploration-kit/"
func _initialize() -> void:
	var source := ROOT+"overlook-rail-v2.png"
	var im := Image.load_from_file(ProjectSettings.globalize_path(source))
	assert(im != null and im.detect_alpha() != Image.ALPHA_NONE,"Rail needs real transparency")
	var bounds := Rect2i()
	var found := false
	for y in range(im.get_height()):
		for x in range(im.get_width()):
			if im.get_pixel(x,y).a < .1: continue
			var pixel := Rect2i(x,y,1,1)
			bounds = bounds.merge(pixel) if found else pixel
			found = true
	assert(found)
	bounds = bounds.grow(2).intersection(Rect2i(Vector2i.ZERO,im.get_size()))
	var texture := AtlasTexture.new()
	texture.atlas = load(source)
	texture.region = Rect2(bounds)
	texture.filter_clip = true
	assert(ResourceSaver.save(texture,ROOT+"overlook-rail-v2.tres") == OK)
	var file := FileAccess.open(ROOT+"overlook-v2-regions.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"source":source,"image_size":[im.get_width(),im.get_height()],"rail_region":[bounds.position.x,bounds.position.y,bounds.size.x,bounds.size.y]},"  ")+"\n")
	print("PASS: overlook rail atlas saved; original unchanged")
	quit()
