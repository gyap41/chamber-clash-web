extends SceneTree
const OUT = "res://docs/art/reviews/projectile-effects-2026-09-13/"
const RAW = "res://.local/projectile-review-frames/"
const V = preload("res://scripts/catalog/weapon_visual_catalog.gd")
func _initialize() -> void: call_deferred("run")
func snapshot(path: String) -> void:
	await process_frame;await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(path)==OK)
func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT);DirAccess.make_dir_recursive_absolute(RAW)
	root.size = Vector2i(1280,900);root.content_scale_size = root.size
	var bg = ColorRect.new();bg.size=Vector2(1280,900);bg.color=Color("34434b");root.add_child(bg)
	var fx = preload("res://scripts/visuals/combat_visuals.gd").new();root.add_child(fx)
	fx.weapon_effect_limit=100
	var actors: Array=[];var bullets: Array=[]
	for id in range(38):
		var p = load("res://scenes/combat/player.tscn").instantiate();root.add_child(p)
		p.set_character(0);p.reset(Vector2(40+(id%8)*160,100+(id/8)*165))
		p.inventory=[p.Weapons.new_inventory_entry(id)];p.update_weapon_art();p.sync_visual()
		p.get_node("Identity").hide();actors.append(p)
		var label=Label.new();label.text="%02d %s"%[id,p.Weapons.definition(id).name]
		label.add_theme_font_size_override("font_size",11);label.position=Vector2(5+(id%8)*160,16+(id/8)*165)
		root.add_child(label)
		var b=load("res://scenes/combat/projectile.tscn").instantiate();root.add_child(b)
		b.launch(p,0,id,0,{"pos":p.position+Vector2(75,-10)});bullets.append(b)
	for frame in range(48):
		fx.step(1.0/24)
		for id in range(38):
			var p=actors[id];var b=bullets[id]
			p.get_node("Animation").advance(1.0/24,false);p.sync_visual()
			b.position=p.position+Vector2(62+(frame%24)*2,-10)
			if frame%24==0:
				b.get_node("Art").samples.clear()
				p.get_node("Animation").fire()
				fx.weapon_event({"kind":"fire","weapon":id,"pos":p.presentation_muzzle(id,0),"angle":0})
			if frame%24==18:fx.weapon_event({"kind":"hit","weapon":id,"pos":p.position+Vector2(108,-10),"angle":0})
			b.get_node("Art").refresh(frame/24.0,Vector2.RIGHT*120)
			b.visible=frame%24<18
		await snapshot(RAW+"bullets-%03d.png"%frame)
		if frame==10:await snapshot(OUT+"bullets-in-game.png")
	for b in bullets:b.queue_free()
	for p in actors:p.queue_free()
	for node in root.get_children():
		if node is Label:node.queue_free()
	fx.clear()
	await process_frame
	var ids=[0,6,25]
	for i in range(3):
		var p=load("res://scenes/combat/player.tscn").instantiate();root.add_child(p)
		p.set_character(0);p.reset(Vector2(240+i*400,430));p.scale=Vector2(3,3)
		p.inventory=[p.Weapons.new_inventory_entry(ids[i])];p.update_weapon_art();p.weapon().clip=0
		p.start_reload();p.get_node("Identity").hide();actors[i]=p
		var label=Label.new();label.text=["Magazine / mechanical","Charge / energy","Rune / magic"][i]
		label.position=Vector2(100+i*400,200);root.add_child(label)
	for frame in range(36):
		for i in range(3):
			var p=actors[i]
			p.state.reload=p.reload_visual_duration*(1.0-float(frame%30)/30.0)
			p.get_node("Animation").advance(1.0/24,false);p.sync_visual()
		await snapshot(RAW+"reload-%03d.png"%frame)
	print("PASS: all projectile sprites/trails/muzzles/impacts and three reload styles rendered")
	quit()
