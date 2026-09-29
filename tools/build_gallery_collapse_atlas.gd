extends SceneTree
# Sprite import only: preserve the generated RGBA pixels and select padded alpha bounds in AtlasTexture.
# The generator did not obey equal-sized cells, so use inspected source-space regions, not a uniform grid.
const ROOT := "res://assets/stages/ashen-foundry-v2/gallery-collapse/"
const REGIONS := {
	"broken_base":Rect2(112,200,412,365),
	"fallen_shaft":Rect2(629,141,550,455),
	"roof_collapse":Rect2(59,759,710,370),
	"fragments":Rect2(854,827,334,256)
}
func _initialize() -> void:
	var atlas = load(ROOT+"atlas.png")
	assert(atlas is Texture2D,"Import atlas.png in Godot before building resources")
	for id in REGIONS:
		var sprite := AtlasTexture.new()
		sprite.atlas = atlas
		sprite.region = REGIONS[id]
		sprite.filter_clip = true
		assert(ResourceSaver.save(sprite,ROOT+id+".tres") == OK)
	print("PASS: four gallery collapse atlas resources; original pixels unchanged")
	quit()
