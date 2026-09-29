extends SceneTree
const Index = preload("res://tools/visual_hub/asset_index.gd")
const Adapter = preload("res://tools/visual_hub/preview_adapter.gd")
const Store = preload("res://tools/visual_hub/conditions.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var index := Index.new()
	index.reload()
	for item in index.enumerate("","ステージ"):
		var viewport := SubViewport.new()
		viewport.size = Vector2i(960,640)
		viewport.disable_3d = true
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(viewport)
		var adapter := Adapter.new()
		viewport.add_child(adapter)
		adapter.initialize(item,Store.defaults())
		assert(adapter.failure.is_empty(),adapter.failure)
		var zoom := minf(960/adapter.bounds.size.x,640/adapter.bounds.size.y)*.94
		viewport.canvas_transform = Transform2D(0,Vector2.ONE*zoom,0,Vector2(480,320)-adapter.bounds.get_center()*zoom)
		await process_frame
		await RenderingServer.frame_post_draw
		assert(viewport.get_texture().get_image().save_png("res://docs/art/production/authored-rooms/views/hub-%s.png" % item.definition.field_id) == OK)
		adapter.finish()
		viewport.free()
	print("PASS: Hub stage overview images captured from current FieldDefinitions")
	quit()
