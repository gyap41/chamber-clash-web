extends SceneTree
const Direction = preload("res://scripts/visuals/character_direction.gd")
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var rig=preload("res://scripts/visuals/rina_directions.gd")
	for direction in [Vector2.UP,Vector2.DOWN,Vector2.LEFT,Vector2.RIGHT]:
		for phase in [0.0,1.0,2.0,3.0,4.0,5.0]:
			assert(rig.shoe_offset(phase,0,direction).is_equal_approx(rig.shoe_offset(phase+3,1,direction)))
			assert(rig.shoe_offset(phase,0,direction).y<=0.001)
			assert(absf(maxf(rig.shoe_offset(phase,0,direction).y,rig.shoe_offset(phase,1,direction).y))<.001)
			assert((rig.body_pose(phase,true,0)*Vector2(0,15)).is_equal_approx(Vector2(0,15)))
	for view in ["front","back","right"]:
		var combined: Image=rig.texture(view,"-foot-0").get_image()
		combined.convert(Image.FORMAT_RGBA8)
		var second: Image=rig.texture(view,"-foot-1").get_image()
		second.convert(Image.FORMAT_RGBA8)
		combined.blend_rect(second,Rect2i(0,0,256,256),Vector2i.ZERO)
		# Use solid alpha rather than antialias fringes to measure the support region.
		var min_x:=256; var max_x:=-1; var max_y:=-1
		for y in range(256):
			for x in range(256):
				if combined.get_pixel(x,y).a>96.0/255.0:
					min_x=mini(min_x,x); max_x=maxi(max_x,x); max_y=maxi(max_y,y)
		assert(absf((min_x+max_x+1)*.5-128)<=.5)
		assert(max_y+1==240)
	assert(Direction.select(Vector2.ZERO,"left")=="left")
	assert(Direction.select(Vector2(1,.99),"front")=="front")
	assert(Direction.select(Vector2(.99,1),"right")=="right")
	var game=load("res://scenes/game/main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	preload("res://tests/helpers/battle.gd").passive_opponents(game)
	game.assign_character(0,0)
	preload("res://tests/helpers/battle.gd").start(game,20)
	var p=game.players[0]
	var a=p.get_node("Animation")
	var views={0.0:"right",PI/2:"front",PI:"left",-PI/2:"back"}
	for angle in views:
		p.state.angle=angle
		p.sync_visual()
		assert(a.body_view==views[angle])
		assert(a.body_facing==(-1 if a.body_view=="left" else 1))
		assert(a.body_back==(a.body_view=="back"))
		var t: Texture2D = p.Characters.Rig.RinaDirections.texture(a.body_view)
		assert(t.get_size()==Vector2(256,256))
		assert(t.get_image().get_used_rect().has_area())
	# Moving left while aiming right is a backpedal, not a mirrored face.
	p.state.angle=0
	p.state.dir=Vector2.LEFT
	a.moving=true
	a.move_phase=1
	p.sync_visual()
	assert(a.body_view=="right" and a.body_facing==1 and a.animation_frame==5)
	# Dodge follows travel even when the aim stays right.
	p.try_dodge()
	p.sync_visual()
	assert(a.body_view=="left" and a.body_facing==-1 and not p.get_node("Weapon").visible)
	# Front view does not mirror when the cursor crosses the vertical axis.
	p.state.roll=0
	for angle in [PI/2-.02,PI/2+.02]:
		p.state.angle=angle
		p.sync_visual()
		assert(a.body_view=="front" and a.body_facing==1)
	print("PASS: Rina four views, diagonal hysteresis, unmirrored front, backpedal and dodge travel-facing")
	game.queue_free()
	quit()
