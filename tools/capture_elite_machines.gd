extends SceneTree
const Registry = preload("res://tools/visual_hub/preview_registry.gd")
const Index = preload("res://tools/visual_hub/asset_index.gd")
const Store = preload("res://tools/visual_hub/conditions.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size = Vector2i(1120,760)
	root.content_scale_size = root.size
	var index = Index.new()
	index.reload()
	var previews: Array = []
	var labels: Array = []
	var title := Label.new()
	title.text = "専用機械・移動射撃 ／ 4方向・通常倍率1.45 ／ 歩行→実攻撃→撃破"
	title.position = Vector2(20,8)
	root.add_child(title)
	var ids := ["ash_ram","triple_ring","fire_pouch_lizard"]
	for row in range(3):
		for col in range(4):
			var container := SubViewportContainer.new()
			container.position = Vector2(col*280,42+row*238)
			root.add_child(container)
			var viewport := SubViewport.new()
			viewport.size = Vector2i(280,202)
			viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
			container.add_child(viewport)
			var settings := Store.defaults()
			settings.action = "歩行"
			settings.background = "実戦"
			settings.guides = false
			settings.aim = col
			var adapter = Registry.new().create_preview(viewport,index.detail("enemy:"+ids[row]),settings)
			adapter.scale = Vector2.ONE*1.45
			adapter.players[1].visible = false
			previews.append(adapter)
			var label := Label.new()
			label.position = container.position+Vector2(8,204)
			label.add_theme_font_size_override("font_size",14)
			root.add_child(label)
			labels.append(label)
	var folder := "res://.local/elite-frames"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	for frame in range(315):
		for i in range(previews.size()):
			var adapter = previews[i]
			var actor = adapter.players[0]
			if frame == 45:
				adapter.conditions.action = "攻撃"
				actor.prepare(adapter.source_position)
				actor.attack_time = .1
			if frame == 300:
				actor.state.inv = 0
				actor.hurt(100)
			for tick in range(4): adapter.advance(1.0/60)
			adapter.players[1].visible = false
			adapter.position = Vector2(140,135)-actor.state.pos*1.45
			labels[i].text = "%s ／ %s" % [actor.spec.name,actor.attack_phase if frame < 300 else "撃破"]
		for remains in get_nodes_in_group("enemy_death_visuals"): remains.step(1.0/15)
		await process_frame
		await RenderingServer.frame_post_draw
		var screenshot := root.get_texture().get_image()
		assert(screenshot.save_png(folder+"/%03d.png" % frame) == OK)
		if frame in [20,68,90,140,302]:
			assert(screenshot.save_png("res://docs/art/production/enemy-animation-v2/elite-%03d.png" % frame) == OK)
	for adapter in previews:
		adapter.finish()
		adapter.free()
	print("PASS: 4 directions, 3 seconds walk, 17 seconds real attacks, mechanical death; 315 frames at 15fps")
	quit()
