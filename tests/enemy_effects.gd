extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var effects = preload("res://scripts/visuals/combat_visuals.gd").new()
	root.add_child(effects)
	for family in ["flame","quill","sentry"]:
		effects.weapon_event({"kind":"enemy_attack","family":family,"pos":Vector2.ZERO,"angle":0.0})
	for variant in ["enemy_fire_seed","enemy_quill"]:
		effects.weapon_event({"kind":"hit","variant":variant,"pos":Vector2.ZERO,"angle":0.0})
	assert(effects.enemy_effects.size() == 5)
	effects.step(.1)
	assert(effects.enemy_effects.size() == 5)
	# Pause is the absence of simulation steps; draw does not advance lifetimes.
	var before: float = effects.enemy_effects[0].age
	await process_frame
	assert(effects.enemy_effects[0].age == before)
	effects.step(.13)
	assert(effects.enemy_effects.is_empty())
	for n in range(80): effects.weapon_event({"kind":"enemy_attack","family":"flame","pos":Vector2.ZERO,"angle":0.0})
	assert(effects.enemy_effects.size() == effects.weapon_effect_limit)
	effects.clear()
	assert(effects.enemy_effects.is_empty())
	if OS.get_cmdline_user_args().has("--capture"):
		root.size = Vector2i(800,440)
		root.content_scale_size = root.size
		var bg := ColorRect.new()
		bg.color = Color("26342b"); bg.size = Vector2(800,440)
		root.add_child(bg); root.move_child(bg,0)
		for n in range(3):
			var family: String = ["sentry","flame","quill"][n]
			var pos := Vector2(130+n*260,180)
			effects.weapon_event({"kind":"enemy_attack","family":family,"pos":pos,"angle":-.2,"reach":72})
			var label := Label.new();label.text=family;label.position=pos-Vector2(30,85);root.add_child(label)
		for n in range(5):
			var bullet = preload("res://scripts/visuals/projectile_art.gd").new()
			root.add_child(bullet); bullet.position=Vector2(150+n*120,320)
			bullet.configure(2,false,false,"enemy_fire_seed","",true)
			bullet.refresh(n*.04,Vector2.RIGHT*300)
		effects.step(.055)
		await process_frame
		await RenderingServer.frame_post_draw
		assert(root.get_texture().get_image().save_png("res://.local/enemy-effects-review.png") == OK)
	print("PASS: enemy attack/impact effect lifetime, pause, caps and cleanup")
	quit()
