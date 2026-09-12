extends SceneTree
const Dodge = preload("res://scripts/visuals/rina_dodge.gd")
func _initialize() -> void:
	assert(Dodge.stage(0)==0)
	assert(Dodge.stage(.039/.38)==0)
	assert(Dodge.stage(.041/.38)==1)
	assert(Dodge.stage(.259/.38)==1)
	assert(Dodge.stage(.261/.38)==2)
	assert(Dodge.stage(1)==2)
	assert(is_zero_approx(Dodge.lift(0)))
	assert(is_zero_approx(Dodge.lift(1)))
	assert(is_equal_approx(Dodge.lift(.15/.38),6))
	for view in ["front","back","right","left"]:
		for pose in range(3):
			var art: Texture2D=Dodge.texture(view,pose)
			assert(art!=null and art.get_size()==Vector2(512,384))
			assert(art.get_image().get_used_rect().has_area())
			assert(Dodge.texture("right",pose)==Dodge.texture("left",pose))
			if pose>0: assert(art!=Dodge.texture(view,pose-1))
	print("PASS: Dedicated Rina dodge assets, three stage timings, symmetric side source and flight lift")
	quit()
