extends SceneTree
const OUT := "res://docs/art/production/root-runner-motion/"
const Registry = preload("res://tools/visual_hub/preview_registry.gd")
const Index = preload("res://tools/visual_hub/asset_index.gd")
const Store = preload("res://tools/visual_hub/conditions.gd")
func _initialize(): call_deferred("run")
func run():
	var bounce := "--bounce" in OS.get_cmdline_user_args()
	var walk_only := "--walk" in OS.get_cmdline_user_args()
	var folder := "res://.local/moss-walk-frames" if walk_only else ("res://.local/moss-bounce-frames" if bounce else "res://.local/moss-tackle-frames")
	var prefix := "walk-motion" if walk_only else ("bounce-motion" if bounce else "tackle-motion")
	var frame_count := 144 if walk_only else 240
	root.size = Vector2i(960,600)
	root.content_scale_size = root.size
	var index = Index.new();index.reload()
	var item = index.detail("enemy:root_runner_prototype")
	var settings = Store.defaults();settings.action="歩行" if walk_only else "攻撃";settings.background="実戦";settings.guides=false
	if bounce: settings.scenario="wall"
	var adapter = Registry.new().create_preview(root,item,settings)
	var source: Vector2 = adapter.source_position
	if not bounce:
		var field = preload("res://scripts/world/authored_rooms.gd").catalog()["cistern"].field
		assert(adapter.arena.configure_field(field,0).is_empty())
		source = Vector2(480,530)
		var found := false
		for y in range(200,650,40):
			for x in range(200,900,40):
				var start := Vector2(x,y)
				var finish := start+Vector2(1,1).normalized()*240
				if adapter.arena.fighter_bounds.grow(-24).has_point(finish) and not adapter.arena.solid(start,24) and not adapter.arena.solid(finish,24) and not adapter.arena.line_blocked(start,finish):
					source=start;found=true;break
			if found: break
		assert(found,"Need a clear long approach for capture")
		adapter.source_position = source
		adapter.target_position = source+Vector2(1,1).normalized()*240
		adapter.players[0].prepare(source)
		adapter.players[1].reset(adapter.target_position)
		assert(not adapter.arena.solid(source,18) and not adapter.arena.solid(adapter.target_position,14))
	adapter.scale = Vector2.ONE*1.2
	adapter.position = Vector2(360,330)-source*1.2
	# A diagnostic enlargement uses the same generated parts and exact same pose.
	var overlay := CanvasLayer.new();root.add_child(overlay)
	var bg := ColorRect.new();bg.color=Color("17232c");bg.position=Vector2(680,80);bg.size=Vector2(260,400);overlay.add_child(bg)
	var large = preload("res://scripts/visuals/root_runner_rig.gd").new();large.position=Vector2(800,220);large.scale=Vector2.ONE*4;overlay.add_child(large)
	var label := Label.new();label.position=Vector2(24,20);label.add_theme_font_size_override("font_size",19);overlay.add_child(label)
	var note := Label.new();note.position=Vector2(690,90);note.text="DETAIL x4 / same facing";overlay.add_child(note)
	var actor = adapter.players[0]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	for frame in range(frame_count):
		for n in range(2): adapter.advance(1.0/60)
		large.facing=actor.rig.facing;large.facing_index=actor.rig.facing_index;large.body_offset=actor.rig.body_offset;large.world=actor.rig.world;large.feet=actor.rig.feet.duplicate(true);large.view=actor.rig.view.duplicate();large.clock=actor.rig.clock;large.queue_redraw()
		label.text="Moss %s / room x1.2 / %s / %.2fs / hits %.0f" % ["walk" if walk_only else "tackle",actor.attack_phase,frame/30.0,adapter.damage_total/.7]
		await process_frame
		await RenderingServer.frame_post_draw
		var image := root.get_texture().get_image()
		assert(image.save_png(ProjectSettings.globalize_path(folder+"/%03d.png" % frame))==OK)
		if frame in [10,48,65,75,78,82,90,103,130]:
			assert(image.save_png(ProjectSettings.globalize_path(OUT+prefix+"-%03d.png" % frame))==OK)
	print("PASS: %s / %d frames, normal scale plus detail" % [prefix,frame_count])
	adapter.finish();adapter.free();quit()
