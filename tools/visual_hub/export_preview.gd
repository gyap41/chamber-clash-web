extends SceneTree
# Explicit small-batch capture using the same adapter as the native Hub.
const Store = preload("res://tools/visual_hub/conditions.gd")
const Index = preload("res://tools/visual_hub/asset_index.gd")
const Registry = preload("res://tools/visual_hub/preview_registry.gd")
const Overlay = preload("res://tools/visual_hub/inspection_overlay.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var args:=OS.get_cmdline_user_args()
	if args.size()!=1: push_error("One job file required"); quit(1); return
	var job:=Store.read(args[0]); var conditions:=Store.normalize(job.get("conditions",{}))
	var ids: Array=job.get("ids",[])
	var out: String=job.get("output","")
	if ids.is_empty() or ids.size()>4 or not out.begins_with(Store.DIRECTORY+"/renders/") or ".." in out:
		push_error("Invalid capture job"); quit(1); return
	var index:=Index.new(); index.reload("res://data/catalog.json","res://data/weapon_visuals.json",true); index.install_game_snapshot()
	root.size=Vector2i(640,400); root.content_scale_size=root.size
	var registry:=Registry.new(); var renderers: Array=[]
	for id in ids:
		var item:=index.detail(id)
		if item.is_empty() or not item.preview: push_error("Unsupported capture ID: "+str(id)); quit(1); return
		var viewport:=SubViewport.new(); viewport.size=Vector2i(640,400); viewport.disable_3d=true; viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS; root.add_child(viewport)
		var adapter=registry.create_preview(viewport,item,conditions)
		if not adapter.failure.is_empty(): push_error(adapter.failure); quit(1); return
		var bounds: Rect2=adapter.bounds
		var zoom: float=conditions.zoom
		if conditions.fit: zoom=minf(640.0/bounds.size.x,400.0/bounds.size.y)*.85
		var center:=bounds.get_center()
		if item.method=="stage" and conditions.camera=="実戦カメラ":
			var field_scale:=minf(1120.0/bounds.size.x,600.0/bounds.size.y)
			zoom=minf(640.0/1120.0,400.0/800.0)*field_scale
			center=Vector2(bounds.get_center().x,bounds.position.y+310.0/field_scale)
		viewport.canvas_transform=Transform2D(0,Vector2.ONE*zoom,0,Vector2(320,200)-center*zoom)
		var overlay:=Overlay.new(); overlay.adapter=adapter; adapter.add_child(overlay)
		renderers.append({"adapter":adapter,"viewport":viewport})
	DirAccess.make_dir_recursive_absolute(out)
	var frames:=clampi(int(job.get("frames",1)),1,36)
	var fps:=12
	var tick:=0
	var time_start:=maxi(0,roundi(float(conditions.time)/float(conditions.dt)))
	conditions.time=time_start*float(conditions.dt)
	for frame in range(frames):
		var target:=time_start+roundi(float(frame)/fps/float(conditions.dt))
		while tick<target:
			for renderer in renderers: renderer.adapter.advance(conditions.dt)
			tick+=1
			# Native CPU particles must receive the same frame-boundary progression.
			await process_frame
		await process_frame; await RenderingServer.frame_post_draw
		for i in range(renderers.size()):
			var image: Image=renderers[i].viewport.get_texture().get_image()
			if image.save_png(out+"/%d-%03d.png" % [i,frame])!=OK: push_error("PNG write failed"); quit(1); return
	for renderer in renderers:
		renderer.adapter.finish(); renderer.viewport.free()
	if Store.save(out+"/result.json",{"ids":ids,"conditions":conditions,"frames":frames,"fps":fps,"width":640,"height":400,"engine":Engine.get_version_info().string})!=OK: quit(1); return
	print("PASS: Visual Hub capture %d targets / %d frames" % [ids.size(),frames]); quit()
