extends SceneTree
const OUT="res://docs/art/reviews/equipment-diversity-2026-09-13/"
func _initialize() -> void:
	call_deferred("run")
func capture(file: String) -> void:
	await process_frame;await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(OUT+file)==OK)
func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	root.size=Vector2i(1280,900)
	root.content_scale_size=Vector2i(1280,900)
	var bg=ColorRect.new();bg.color=Color("405055");bg.size=Vector2(1280,900);root.add_child(bg)
	var actors: Array=[];var labels: Array=[]
	for id in range(38):
		var col=id%8;var row=id/8
		var p=load("res://scenes/combat/player.tscn").instantiate();root.add_child(p)
		p.set_character(id-20 if id>=20 and id<=27 else 0)
		p.reset(Vector2(80+col*160,130+row*160));p.scale=Vector2(1.2,1.2)
		p.inventory=[p.Weapons.new_inventory_entry(id)];p.update_weapon_art();p.get_node("Identity").hide()
		p.state.angle=0;p.sync_visual();actors.append(p)
		var label=Label.new();label.text="%02d %s"%[id,p.Weapons.definition(id).name]
		label.add_theme_font_size_override("font_size",11);label.position=Vector2(8+col*160,15+row*160)
		root.add_child(label);labels.append(label)
	await capture("weapons-right.png")
	for p in actors:
		p.state.angle=PI;p.sync_visual();p.get_node("Animation").fire();p.get_node("Animation").queue_redraw()
	await capture("weapons-left-fire.png")
	for p in actors:p.queue_free()
	for label in labels:label.queue_free()
	await process_frame
	for id in range(35):
		var col=id%7;var row=id/7
		var icon=preload("res://scripts/ui/hud_relic_icon.gd").new();root.add_child(icon)
		icon.position=Vector2(60+col*180,60+row*160);icon.size=Vector2(40,40);icon.configure(id,1,false,0,false)
		var label=Label.new();label.text="%02d %s"%[id,preload("res://scripts/catalog/relic_catalog.gd").definition(id).name]
		label.position=Vector2(10+col*180,115+row*160);label.add_theme_font_size_override("font_size",13);root.add_child(label)
	await capture("relics-hud.png")
	print("PASS: all 38 weapons in both aim directions and all 35 relic HUD icons captured")
	quit()
