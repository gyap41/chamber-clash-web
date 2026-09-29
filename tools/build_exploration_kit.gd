extends SceneTree
# Select inspected cells, then trim alpha bounds without editing source PNGs.
const ROOT := "res://assets/stages/ashen-foundry-v2/exploration-kit/"
const CELLS := {
	"archive_shelf":["archive-storage-v1",Rect2(0,0,.62,1)],
	"sealed_storage":["archive-storage-v1",Rect2(.65,0,.35,1)],
	"sealed_gate":["refinement",Rect2(0,0,.5,.5)],
	"reading_desk":["refinement",Rect2(.5,0,.5,.5)],
	"seat":["refinement",Rect2(0,.5,.5,.5)],
	"records":["refinement",Rect2(.5,.5,.5,.5)],
	"cistern":["architecture",Rect2(0,0,.52,.5)],
	"altar":["architecture",Rect2(.56,0,.44,.5)],
	"fallen_gate":["architecture",Rect2(0,.5,.67,.5)],
	"plinth":["architecture",Rect2(.69,.5,.31,.5)],
	"nest":["discovery",Rect2(0,0,.52,.5)],
	"tablet":["discovery",Rect2(.55,0,.45,.5)],
	"shoring":["discovery",Rect2(0,.51,.50,.49)],
	"carapace":["discovery",Rect2(.51,.51,.49,.49)],
	"soil_roots":["nature",Rect2(0,0,.5,.5)],
	"floor_root":["nature",Rect2(.5,0,.5,.5)],
	"papers":["nature",Rect2(0,.5,.5,.5)],
	"relic_chest":["nature",Rect2(.5,.5,.5,.5)]
}
func _initialize() -> void:
	var manifest := {}
	for id in CELLS:
		var source: String = ROOT+CELLS[id][0]+".png"
		var im := Image.load_from_file(ProjectSettings.globalize_path(source))
		assert(im != null and im.detect_alpha() != Image.ALPHA_NONE,"Sprite sheet must have real alpha: "+source)
		var cell: Rect2 = CELLS[id][1]
		var scan := Rect2i(cell.position*Vector2(im.get_size()),cell.size*Vector2(im.get_size()))
		var bounds := Rect2i()
		var found := false
		for y in range(scan.position.y,scan.end.y):
			for x in range(scan.position.x,scan.end.x):
				if im.get_pixel(x,y).a < .1: continue
				var pixel := Rect2i(x,y,1,1)
				bounds = bounds.merge(pixel) if found else pixel
				found = true
		assert(found,"Empty cell: "+id)
		# A cell touching an internal scan edge would cut off the requested silhouette.
		assert(bounds.position.x > scan.position.x and bounds.end.x < scan.end.x,"Horizontal clipping: "+id)
		assert(bounds.position.y > scan.position.y and bounds.end.y < scan.end.y,"Vertical clipping: "+id)
		bounds = bounds.grow(2).intersection(scan)
		var sprite := AtlasTexture.new()
		sprite.atlas = load(source)
		sprite.region = Rect2(bounds)
		sprite.filter_clip = true
		assert(ResourceSaver.save(sprite,ROOT+id+".tres") == OK)
		manifest[id] = {"source":source,"image_size":[im.get_width(),im.get_height()],"region":[bounds.position.x,bounds.position.y,bounds.size.x,bounds.size.y]}
	var depth := AtlasTexture.new()
	depth.atlas = load(ROOT+"depth.png")
	assert(depth.atlas != null)
	depth.region = Rect2(Vector2.ZERO,depth.atlas.get_size())
	depth.filter_clip = true
	assert(ResourceSaver.save(depth,ROOT+"depth.tres") == OK)
	var file := FileAccess.open(ROOT+"regions.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(manifest,"  ")+"\n")
	print("PASS: eighteen transparent sprites and one distant view; source pixels preserved")
	quit()
