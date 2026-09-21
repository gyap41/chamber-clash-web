extends SceneTree
const Field = preload("res://scripts/world/field_definition.gd")
const Art = preload("res://data/stage_themes/workshop_showcase.tres")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var field := Field.new()
	field.field_id = "junction-regression"
	field.theme = Art
	field.floor_regions = [Rect2(128,128,864,384)]
	field.spawns = PackedVector2Array([Vector2(700,430)])
	field.walls = [Rect2(400,200,24,160),Rect2(250,260,150,32),Rect2(424,260,150,32),Rect2(350,360,124,32),Rect2(350,152,124,48)]
	field.wall_ids = PackedStringArray(["stem","left","right","bottom","top"])
	field.wall_materials = {"stem":"top","left":"face","right":"face","bottom":"face","top":"face"}
	var arena = load("res://scenes/world/arena.tscn").instantiate()
	root.add_child(arena)
	for count in [2,3,4,5]:
		var sample = field.duplicate(true)
		sample.walls.resize(count)
		sample.wall_ids.resize(count)
		for id in sample.wall_materials.keys():
			if id not in sample.wall_ids: sample.wall_materials.erase(id)
		assert(arena.configure_field(sample,1).is_empty())
		var stem = arena.get_node("Walls/Wall1")
		assert(stem.joint_caps.size() == maxi(1,count-2)) # Both arms share one cap.
		assert(stem.upper_extension == (84 if count == 5 else 0))
		var caps = stem.joint_caps.duplicate()
		assert(stem.collision_rect() == field.walls[0])
		var walls = arena.get_node("Walls").get_children()
		walls.reverse()
		stem.connect_faces(walls)
		assert(stem.joint_caps.size() == caps.size())
		for cap in caps: assert(cap in stem.joint_caps)
		assert(arena.solid(Vector2(412,220),2))
		assert(not arena.solid(Vector2(380,220),2))
	arena.queue_free()
	await process_frame
	print("PASS: inner/outer L joins, shared T cap, lower face connection, non-default thickness, order independence and collision")
	quit()
