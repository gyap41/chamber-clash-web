extends SceneTree
const OUT = "res://docs/archive/2026-09-12/art-organization/unused-candidates/raw-frames/character-integration/"
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	root.size=Vector2i(1120,660)
	var bg=ColorRect.new()
	bg.color=Color("35454c")
	bg.size=Vector2(1120,660)
	root.add_child(bg)
	var actors: Array = []
	for row in range(3):
		var label=Label.new()
		label.text=["WALK / FRONT", "WALK / BACK", "DODGE / CHARACTER STYLE"][row]
		label.position=Vector2(12,20+row*210)
		root.add_child(label)
		for id in range(8):
			var p=load("res://scenes/combat/player.tscn").instantiate()
			root.add_child(p)
			p.set_character(id)
			p.reset(Vector2(75+id*139,150+row*210))
			p.scale=Vector2(1.7,1.7)
			p.get_node("Identity").hide()
			actors.append(p)
	for frame in range(60):
		for i in range(actors.size()):
			var p=actors[i]
			var row:=i/8
			var anim=p.get_node("Animation")
			p.state.angle=-PI/2 if row==1 else 0.0
			p.state.dir=Vector2.UP if row==1 else Vector2.RIGHT
			p.state.roll=p.dodge_duration*(1.0-float(frame%30)/30.0) if row==2 else 0.0
			anim.advance(.025,row!=2)
			p.sync_visual()
		await process_frame
		await RenderingServer.frame_post_draw
		assert(root.get_texture().get_image().save_png(OUT+"motion-%02d.png" % frame)==OK)
	print("PASS: Eight-character renderer motion capture")
	quit()
