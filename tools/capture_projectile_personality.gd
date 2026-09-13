extends SceneTree
const OUT="res://docs/art/reviews/projectile-personality-2026-09-13/"
const RAW="res://.local/projectile-personality-frames/"
const IDS=[0,6,9,5,16,17,13,10,12,33,36,37]
class Lane:
	var projectile_bounds: Rect2
	func solid(_pos: Vector2,_radius: float) -> bool: return false
	func line_blocked(_a: Vector2,_b: Vector2) -> bool: return false
func _initialize() -> void:call_deferred("run")
func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT);DirAccess.make_dir_recursive_absolute(RAW)
	root.size=Vector2i(1440,850);root.content_scale_size=root.size
	var bg=ColorRect.new();bg.size=Vector2(1440,850);bg.color=Color("26343d");root.add_child(bg)
	var fx=preload("res://scripts/visuals/combat_visuals.gd").new();root.add_child(fx)
	var actors=[];var shots=[];var lanes=[]
	for i in range(IDS.size()):
		var origin=Vector2((i%4)*360,(i/4)*275)
		var label=Label.new();label.text="%02d %s"%[IDS[i],preload("res://scripts/catalog/weapon_catalog.gd").definition(IDS[i]).name]
		label.position=origin+Vector2(12,20);label.add_theme_font_size_override("font_size",15);root.add_child(label)
		var p=load("res://scenes/combat/player.tscn").instantiate();root.add_child(p)
		p.set_character(0);p.reset(origin+Vector2(44,145));p.inventory=[p.Weapons.new_inventory_entry(IDS[i])];p.update_weapon_art();p.sync_visual();p.get_node("Identity").hide();actors.append(p)
		var b=load("res://scenes/combat/projectile.tscn").instantiate();root.add_child(b);shots.append(b)
		var lane=Lane.new();lane.projectile_bounds=Rect2(origin+Vector2(10,55),Vector2(330,170));lanes.append(lane)
		b.launch(p,0,IDS[i],0,{"pos":p.position+Vector2(32,-10),"parcel":IDS[i]==17})
	for frame in range(72):
		fx.step(1.0/30)
		for i in range(IDS.size()):
			var p=actors[i];var b=shots[i]
			if b.state.life<=0 or frame==0:
				b.launch(p,0,IDS[i],0,{"pos":p.position+Vector2(32,-10),"parcel":IDS[i]==17})
				p.get_node("Animation").fire();fx.weapon_event({"kind":"fire","weapon":IDS[i],"pos":p.presentation_muzzle(IDS[i],0),"angle":0})
			b.step(1.0/30,lanes[i],null)
			if b.state.life<=0:fx.weapon_event({"kind":"split" if IDS[i] in [9,17] else "hit","weapon":IDS[i],"variant":"parcel" if IDS[i]==17 else "","pos":b.position,"angle":0})
			b.visible=b.state.life>0
			p.get_node("Animation").advance(1.0/30,false);p.sync_visual()
		await process_frame;await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(RAW+"%03d.png"%frame)
		if frame==8:root.get_texture().get_image().save_png(OUT+"comparison.png")
	print("PASS: 12 projectile profiles rendered with actual flight updates (isolated lanes, no damage/fragment simulation)")
	quit()
