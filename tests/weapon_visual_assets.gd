extends SceneTree
const V = preload("res://scripts/catalog/weapon_visual_catalog.gd")
func _initialize() -> void:
	for id in range(38):
		var p := V.profile(id)
		assert(ResourceLoader.exists(str(p.bullet)))
		assert(ResourceLoader.exists(str(p.body.texture)))
		assert(V.texture(str(p.bullet)).resource_path == str(p.bullet))
		assert(V.vec(p.bullet_size).x>0 and V.vec(p.bullet_size).y>0)
		for event in ["muzzle","hit","bounce","split","reload_complete"]:
			var spec := V.effect(id,event)
			assert(not spec.is_empty() and float(spec.duration)>0)
			assert(ResourceLoader.exists(str(spec.texture)))
			var tex := V.texture(str(spec.texture))
			assert(tex.resource_path == str(spec.texture))
			if int(spec.frames)==4: assert(tex.get_size()==Vector2(512,128))
	for spec in V.data.variants.values(): assert(ResourceLoader.exists(str(spec.texture)))
	assert(ResourceLoader.exists(str(V.data.gravity_core)))
	print("PASS: all 38 weapon visual profiles, projectile variants and registered effect textures exist")
	quit()
