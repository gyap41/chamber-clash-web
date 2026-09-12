extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var game = load("res://scenes/game/main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	preload("res://tests/helpers/battle.gd").passive_opponents(game)
	preload("res://tests/helpers/battle.gd").start(game,20)
	var p = game.players[0]
	var anim = p.get_node("Animation")
	var rig = preload("res://scripts/visuals/character_rig.gd")
	for id in range(8):
		game.assign_character(0,id)
		p.reset(Vector2(350,450))
		assert(p.Characters.art(id).atlas != p.Characters.SHEET)
		for row in ["front","back"]:
			for part in ["body","foot-0","foot-1"]:
				var image: Image = rig.texture(id,row+"-"+part).get_image()
				assert(image.get_used_rect().has_area())
		p.state.angle = -PI/2
		p.sync_visual()
		assert(anim.body_back and p.get_node("Weapon").z_index == -1)
		p.state.angle = PI/2
		p.sync_visual()
		assert(not anim.body_back and p.get_node("Weapon").z_index == 1)
		p.state.dir = Vector2.LEFT
		p.state.angle = 0
		p.try_dodge()
		assert(is_equal_approx(p.state.inv,.31))
		assert(is_equal_approx(p.state.roll,.38 if id==0 else .26))
		p.sync_visual()
		assert(anim.animation_name == "roll" and anim.body_facing == -1)
		assert(not p.get_node("Weapon").visible)
		p.state.roll=0
		anim.moving=true
		anim.move_phase=1
		p.sync_visual()
		assert(anim.animation_frame==5 and anim.animation_name=="move")
		var first: Vector2 = rig.RinaDirections.shoe_offset(1,0,Vector2.UP)
		assert(first.is_equal_approx(rig.RinaDirections.shoe_offset(4,1,Vector2.UP)))
	print("PASS: Eight fixed rigs, front/back, alternating feet, roll facing, timing and weapon layering")
	game.queue_free()
	quit()
