extends SceneTree
const V=preload("res://scripts/catalog/weapon_visual_catalog.gd")
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var game=load("res://scenes/game/main.tscn").instantiate();root.add_child(game);game.set_physics_process(false)
	preload("res://tests/helpers/battle.gd").passive_opponents(game)
	for id in [37,8]:
		game.reset_round();preload("res://tests/helpers/battle.gd").start(game,id)
		game.fire(0)
		var palette: Array=V.profile(id).palette
		assert(game.shots.size()==palette.size())
		for i in range(game.shots.size()):
			var shot=game.shots[i];var art=shot.get_node("Art")
			assert(art.shot_color==Color(palette[i]))
			assert(art.material.get_shader_parameter("shot_color")==Color(palette[i]))
			assert(art.get_node("Trail").material==null and not art.get_node("Trail").use_parent_material)
			shot.notify_visual("hit",shot.position)
			assert(game.arena.get_node("CombatVisuals").named_effects.back().visual_color==palette[i])
			assert(shot.radius==(4.0 if id==8 else 5.0))
	# Small rounds are thickened without increasing their gameplay collision radius.
	for id in [0,4,19,20,21,24,26,27,29,30,31]:
		game.spawn_shot(0,id,0)
		var shot=game.shots.back();var art=shot.get_node("Art")
		assert(art.texture.get_height()*art.base_scale.y>=8.0 and shot.radius==5.0)
	# Switching away cannot retain a rainbow material; cached UI materials are reusable.
	var p=game.players[0];p.inventory=[p.Weapons.new_inventory_entry(37),p.Weapons.new_inventory_entry(0)];p.state.gun=0;p.update_weapon_art()
	assert(p.get_node("Weapon/Sprite").material!=null)
	p.state.gun=1;p.update_weapon_art();assert(p.get_node("Weapon/Sprite").material==null)
	assert(V.body_material(37,Vector2(40,28))==V.body_material(37,Vector2(40,28)))
	print("PASS: per-pellet spectrum reaches sprites, trails and impacts; legible dimensions retain collision; material reset/cache")
	game.queue_free();quit()
