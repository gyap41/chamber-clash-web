extends SceneTree
const Visual = preload("res://scripts/visuals/remaining_machine_visual.gd")
const Preview = preload("res://scripts/dev/candidate_preview.gd")
const Registry = preload("res://scripts/catalog/enemy_registry.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	assert(Preview.active.is_empty(),"Default art must not require a candidate launch flag")
	for id in Visual.IDS:
		assert(Preview.errors.is_empty())
		assert(Visual.sheets.has(id) and Visual.bounds[id].size() == 9)
		var texture: Texture2D = Visual.sheets[id]
		assert(texture.resource_path.begins_with("res://assets/first-workshop/enemies/remaining-machines/"))
		for rect in Visual.bounds[id]:
			assert(rect.has_area() and Rect2(Vector2.ZERO,texture.get_size()).encloses(rect))
		for row in range(3):
			assert(Visual.factor(id,row) > 0 and Visual.factor(id,row) < 1)
		var actor = load("res://scenes/combat/player.tscn").instantiate()
		actor.set_script(Registry.script_for(id))
		root.add_child(actor)
		actor.prepare(Vector2(300,300))
		assert(actor.enemy_visual_snapshot().enemy_id == id)
		actor.free()
	assert(Visual.column(0) == 2 and Visual.column(PI) == 2)
	assert(Visual.column(PI/2) == 0 and Visual.column(-PI/2) == 1)
	assert(Visual.pose({"phase":"spit","remaining":.5,"shot_interval":.5}).kick == 1)
	assert(Visual.pose({"phase":"spit","remaining":.5,"shot_interval":.5,"death_progress":.1}).kick == 0)
	print("PASS: four distinct machine sheets, nine valid regions, actor IDs, direction and death/shot synchronization")
	quit()
