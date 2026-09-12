extends SceneTree
const OUT="res://docs/art/reviews/rina-dodge-2026-09-12/"
const RAW="res://docs/archive/2026-09-12/art-organization/unused-candidates/raw-frames/rina-dodge-2026-09-12/"
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	DirAccess.make_dir_recursive_absolute(RAW)
	DirAccess.make_dir_recursive_absolute(OUT)
	root.size=Vector2i(1024,700)
	var bg=ColorRect.new()
	bg.color=Color("405055")
	bg.size=Vector2(1024,700)
	root.add_child(bg)
	var nodes: Array=[bg]
	var players: Array=[]
	var angles=[PI/2,-PI/2,0.0,PI]
	for row in range(3):
		var label=Label.new()
		label.text=["IDLE: FRONT / BACK / RIGHT / LEFT","WALK: SAME SCALE AND FOOT BASELINE","DODGE: SLOW REVIEW"][row]
		label.position=Vector2(15,12+row*225)
		root.add_child(label); nodes.append(label)
		for col in range(4):
			var p=load("res://scenes/combat/player.tscn").instantiate()
			root.add_child(p); nodes.append(p)
			p.set_character(0)
			p.reset(Vector2(128+col*256,165+row*225))
			p.scale=Vector2(2.2,2.2)
			p.get_node("Identity").hide()
			p.state.angle=angles[col]
			p.state.dir=Vector2.from_angle(angles[col])
			players.append(p)
	for frame in range(64):
		for i in range(players.size()):
			var p=players[i]
			var row:=i/4
			# Include the return to standing so size/pivot discontinuities are visible.
			p.state.roll=.38*(1.0-float(frame%32)/24.0) if row==2 and frame%32<24 else 0.0
			p.get_node("Animation").advance(.025,row==1)
			p.sync_visual()
		await process_frame
		await RenderingServer.frame_post_draw
		assert(root.get_texture().get_image().save_png(RAW+"motion-%02d.png" % frame)==OK)
	for node in nodes: node.queue_free()
	await process_frame
	root.size=Vector2i(1120,800)
	var game=load("res://scenes/game/main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	preload("res://tests/helpers/battle.gd").passive_opponents(game)
	game.assign_character(0,0); game.assign_character(1,5)
	preload("res://tests/helpers/battle.gd").start(game,20)
	var p=game.players[0]; var q=game.players[1]
	p.state.pos=Vector2(340,430); q.state.pos=Vector2(730,430)
	p.state.angle=0; q.state.angle=PI
	p.sync_visual(); q.sync_visual()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(OUT+"battle.png")==OK)
	print("PASS: Matched Rina views and game-screen capture")
	quit()
