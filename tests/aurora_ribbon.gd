extends SceneTree
func _initialize() -> void:
	var art=preload("res://scripts/visuals/projectile_art.gd").new()
	art.profile=preload("res://scripts/catalog/weapon_visual_catalog.gd").profile(37)
	art.samples.assign([Vector2(0,0),Vector2(20,0),Vector2(40,0),Vector2(40,20),Vector2(40,40)])
	var points=art.aurora_curve(60)
	assert(points.size()>10 and points.size()<40)
	assert(points[0].is_equal_approx(Vector2(20,0)))
	assert(points[-1].is_equal_approx(Vector2(40,40)))
	for i in range(1,points.size()):assert(points[i-1].distance_to(points[i])<4)
	for i in range(7):assert(art.rainbow_color(i/6.0).is_equal_approx(Color(art.profile.palette[i])))
	assert(art.rainbow_color(.25)!=art.rainbow_color(.3))
	art.samples.clear();assert(art.aurora_curve(80).is_empty())
	art.free();print("PASS: bounded continuous rainbow curve, all seven palette stops and smooth interpolation");quit()
