extends SceneTree
const Art=preload("res://scripts/visuals/character_directions.gd")
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var game=load("res://scenes/game/main.tscn").instantiate()
	root.add_child(game);game.set_physics_process(false)
	preload("res://tests/helpers/battle.gd").passive_opponents(game)
	preload("res://tests/helpers/battle.gd").start(game,20)
	var p=game.players[0];var anim=p.get_node("Animation")
	for id in range(1,8):
		game.assign_character(0,id);p.reset(Vector2(350,450))
		for view in ["front","back","side"]:
			var support: Image=Art.texture(id,view+"-foot-0").get_image()
			support.convert(Image.FORMAT_RGBA8)
			var other: Image=Art.texture(id,view+"-foot-1").get_image()
			other.convert(Image.FORMAT_RGBA8)
			assert(support.get_used_rect().has_area() and other.get_used_rect().has_area())
			support.blend_rect(other,Rect2i(0,0,256,256),Vector2i.ZERO)
			var min_x=256;var max_x=-1;var max_y=-1
			for y in range(256):
				for x in range(256):
					if support.get_pixel(x,y).a>96.0/255:
						min_x=mini(min_x,x);max_x=maxi(max_x,x);max_y=maxi(max_y,y)
			assert(absf((min_x+max_x+1)*.5-128)<=.5)
			assert(max_y+1==240)
			for stage in range(3):
				var pose=Art.texture(id,view+"-dodge-"+str(stage))
				assert(pose.get_size()==Vector2(512,384) and pose.get_image().get_used_rect().has_area())
		var views={0.0:"right",PI/2:"front",PI:"left",-PI/2:"back"}
		for angle in views:
			p.state.angle=angle;p.sync_visual()
			assert(anim.body_view==views[angle])
			assert(anim.body_facing==(-1 if anim.body_view=="left" else 1))
			assert(p.get_node("Weapon").z_index==(-1 if anim.body_view=="back" else 1))
		p.state.angle=0;p.state.dir=Vector2.LEFT
		p.try_dodge();p.sync_visual()
		assert(anim.body_view=="left" and not p.get_node("Weapon").visible)
		assert(is_equal_approx(p.state.roll,.26) and is_equal_approx(p.state.inv,.31))
	assert(Art.dodge_stage(.149)==0 and Art.dodge_stage(.151)==1)
	assert(Art.dodge_stage(.719)==1 and Art.dodge_stage(.721)==2)
	print("PASS: Seven directional rigs, support anchors, dedicated poses, facing and unchanged dodge timing")
	game.queue_free();quit()
