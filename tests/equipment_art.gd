extends SceneTree
const Weapons = preload("res://scripts/catalog/weapon_catalog.gd")
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var p = load("res://scenes/combat/player.tscn").instantiate()
	root.add_child(p)
	for id in range(38):
		if id == 20: continue
		p.set_character(id-20 if id>=21 and id<=27 else 0);p.reset(Vector2(300,300))
		p.inventory=[Weapons.new_inventory_entry(id)];p.update_weapon_art()
		assert(p.weapon().id == id)
		var sprite: Sprite2D = p.get_node("Weapon/Sprite")
		assert(sprite.texture.atlas.resource_path.contains("equipment/guns/"))
		assert(is_equal_approx(sprite.scale.x,sprite.scale.y))
		for angle in [0.0,PI,PI/2,-PI/2]:
			p.state.angle=angle;p.sync_visual()
			var sign_y := -1.0 if sprite.flip_v else 1.0
			var grip: Vector2 = sprite.position+(Weapons.EQUIPMENT_POINTS[id][0]-Vector2(.5,.5))*sprite.texture.get_size()*sprite.scale*Vector2(1,sign_y)
			assert(grip.distance_to(Vector2(8,0))<.01)
			assert(p.equipment_muzzle().x>grip.x)
		p.state.roll=p.dodge_duration;p.sync_visual()
		assert(not p.get_node("Weapon").visible)
	for id in range(35):
		var art = preload("res://scripts/ui/hud_assets.gd").texture("relic_%02d"%id)
		assert(art.resource_path.contains("equipment/relics/") and art.get_size()==Vector2(96,96))
	p.queue_free()
	await process_frame
	print("PASS: equipment textures, aspect ratio, four-direction grip, muzzle and dodge visibility")
	quit()
