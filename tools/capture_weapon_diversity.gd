extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	root.size=Vector2i(900,800)
	var bg=ColorRect.new();bg.color=Color("405055");bg.size=Vector2(900,800);root.add_child(bg)
	for row in range(4):
		for column in range(4):
			var id=[0,6,5,12][column]
			var p=load("res://scenes/combat/player.tscn").instantiate();root.add_child(p)
			p.set_character(0);p.reset(Vector2(100+column*220,150+row*155));p.scale=Vector2(1.5,1.5)
			p.inventory=[p.Weapons.new_inventory_entry(id)];p.update_weapon_art()
			p.get_node("Identity").hide()
			p.state.angle=[PI/2,-PI/2,0.0,PI][row];p.sync_visual()
			if row>=2:p.get_node("Animation").fire();p.get_node("Animation").queue_redraw()
			if row==0:
				var label=Label.new();label.text=str(p.Weapons.definition(id).name);label.position=Vector2(30+column*220,20);root.add_child(label)
	for id in range(9):
		var icon=preload("res://scripts/ui/hud_relic_icon.gd").new();root.add_child(icon)
		icon.position=Vector2(100+id*100,740);icon.size=Vector2(32,32);icon.configure(id,1,false,0,false)
	await process_frame;await RenderingServer.frame_post_draw
	var out="res://docs/art/reviews/weapon-diversity-2026-09-12/in-game.png"
	assert(root.get_texture().get_image().save_png(out)==OK)
	print("PASS: four-direction equipment and HUD capture")
	quit()
