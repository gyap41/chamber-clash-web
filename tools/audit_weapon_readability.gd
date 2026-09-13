extends SceneTree
const OUT="res://docs/art/reviews/weapon-readability-audit-2026-09-13/"
func _initialize() -> void:call_deferred("run")
func snapshot(file: String) -> void:
	await process_frame;await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(OUT+file)==OK)
func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	root.size=Vector2i(1408,920);root.content_scale_size=root.size
	var bg=ColorRect.new();bg.size=Vector2(1408,920);bg.color=Color("405055");root.add_child(bg)
	var actors=[];var bullets=[];var rows=[]
	for id in range(38):
		var origin=Vector2((id%8)*176,(id/8)*180)
		var p=load("res://scenes/combat/player.tscn").instantiate();root.add_child(p)
		p.set_character(0);p.reset(origin+Vector2(38,110));p.inventory=[p.Weapons.new_inventory_entry(id)]
		p.update_weapon_art();p.sync_visual();p.get_node("Identity").hide();actors.append(p)
		var label=Label.new();label.text="%02d %s"%[id,p.Weapons.definition(id).name]
		label.position=origin+Vector2(5,15);label.size=Vector2(166,35);label.clip_text=true;label.add_theme_font_size_override("font_size",11);root.add_child(label)
		var b=load("res://scenes/combat/projectile.tscn").instantiate();root.add_child(b)
		b.launch(p,0,id,0,{"pos":origin+Vector2(140,100)});bullets.append(b)
		var art=b.get_node("Art");var weapon=p.get_node("Weapon/Sprite")
		var size=weapon.texture.get_size()*weapon.scale
		var shot_size=art.texture.get_size()*art.scale
		var detail=Label.new();detail.text="gun %.0fx%.0f / shot %.0fx%.0f"%[size.x,size.y,shot_size.x,shot_size.y]
		detail.position=origin+Vector2(5,150);detail.add_theme_font_size_override("font_size",10);root.add_child(detail)
		rows.append({"id":id,"name":p.Weapons.definition(id).name,"body_size":[size.x,size.y],"bullet_size":[shot_size.x,shot_size.y],"radius":b.radius,"speed":b.speed,"body_scale":[weapon.scale.x,weapon.scale.y]})
	await snapshot("all-38-right.png")
	for p in actors:p.state.angle=PI;p.sync_visual()
	await snapshot("all-38-left.png")
	var file=FileAccess.open(OUT+"runtime-measurements.json",FileAccess.WRITE);file.store_string(JSON.stringify(rows,"  "));file.close()
	print("PASS: 38 weapon bodies and projectiles measured at scale 1, two aim directions captured")
	quit()
