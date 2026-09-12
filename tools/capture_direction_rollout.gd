extends SceneTree
const OUT="res://docs/art/reviews/character-directions-2026-09-12/"
const RAW="res://docs/archive/2026-09-12/art-organization/unused-candidates/raw-frames/character-directions-2026-09-12/"
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	DirAccess.make_dir_recursive_absolute(RAW)
	DirAccess.make_dir_recursive_absolute(OUT)
	root.size=Vector2i(1120,690)
	var bg=ColorRect.new();bg.color=Color("405055");bg.size=Vector2(1120,690);root.add_child(bg)
	var actors: Array=[];var labels: Array=[]
	var names=["RINA","SORA","KOHAKU","BOLT","MEI","LUNA","RATTLE","CROW"]
	for row in range(3):
		var label=Label.new();label.position=Vector2(10,8+row*225);root.add_child(label);labels.append(label)
		for id in range(8):
			var p=load("res://scenes/combat/player.tscn").instantiate();root.add_child(p)
			p.set_character(id);p.reset(Vector2(70+id*140,175+row*225));p.scale=Vector2(1.7,1.7)
			p.get_node("Identity").hide();actors.append(p)
			if row==0:
				var title=Label.new();title.text=names[id];title.position=Vector2(40+id*140,38);root.add_child(title)
	var angles=[PI/2,-PI/2,0.0,PI]
	for frame in range(128):
		var view=frame/32;var tick=frame%32
		for row in range(3): labels[row].text=["IDLE","WALK","DODGE / NORMALIZED REVIEW"][row]+" / "+["FRONT","BACK","RIGHT","LEFT"][view]
		for i in range(actors.size()):
			var p=actors[i];var row=i/8
			p.state.angle=angles[view];p.state.dir=Vector2.from_angle(angles[view])
			p.state.roll=p.dodge_duration*(1-float(tick)/24) if row==2 and tick<24 else 0.0
			p.get_node("Animation").advance(.025,row==1);p.sync_visual()
		await process_frame;await RenderingServer.frame_post_draw
		assert(root.get_texture().get_image().save_png(RAW+"motion-%03d.png"%frame)==OK)
	print("PASS: Eight-character four-direction idle/walk/dodge capture")
	quit()
