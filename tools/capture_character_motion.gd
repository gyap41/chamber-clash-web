extends SceneTree
const OUT = "res://docs/art/reviews/character-motion-2026-09-21/"
const RAW = "res://.local/rich-motion-frames/"
const Rig = preload("res://scripts/visuals/character_rig.gd")
class PreviousMotion extends Node2D:
	var actor
	func _draw() -> void:
		var anim = actor.get_node("Animation")
		var value = anim.snapshot
		if value == null: return
		draw_set_transform(Vector2(0,15),0,Vector2(1,.25))
		draw_circle(Vector2.ZERO,16,Color(.04,.06,.06,.25))
		var base := Transform2D(0,Vector2(anim.body_facing,1),0,Vector2.ZERO)
		var phase: float = anim.move_phase
		if value.direction.dot(Vector2.from_angle(value.angle)) < -.2: phase = -phase
		Rig.render(self,value.character_id,base,anim.body_back,value.moving,
			phase,value.direction*Vector2(anim.body_facing,1),-1,anim.elapsed,Color.WHITE,anim.body_view)

func _initialize() -> void: call_deferred("run")
func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	DirAccess.make_dir_recursive_absolute(RAW)
	var stage := Node2D.new()
	root.add_child(stage)
	root.size = Vector2i(1152,400)
	root.content_scale_size = root.size
	var bg := ColorRect.new()
	bg.size = root.size
	bg.color = Color("26353e")
	stage.add_child(bg)
	var status := Label.new()
	status.position = Vector2(14,10)
	stage.add_child(status)
	var actors: Array = []
	var previous: Array = []
	for row in range(2):
		var label := Label.new()
		label.text = "BEFORE / procedural motion" if row == 0 else "AFTER / keyframes + transitions"
		label.position = Vector2(14,45+row*172)
		stage.add_child(label)
	for id in range(8):
		var p = load("res://scenes/combat/player.tscn").instantiate()
		stage.add_child(p)
		p.set_character(id)
		p.reset(Vector2(72+id*144,329))
		p.scale = Vector2.ONE*1.7
		p.get_node("Identity").hide()
		actors.append(p)
		var old := PreviousMotion.new()
		old.actor = p
		old.position = Vector2(72+id*144,157)
		old.scale = p.scale
		stage.add_child(old)
		previous.append(old)
		var name_label := Label.new()
		name_label.text = p.Characters.definition(id).name
		name_label.position = Vector2(25+id*144,371)
		stage.add_child(name_label)
	for frame in range(210):
		var time := frame/30.0
		var moving := (time >= 1.3 and time < 3.0) or (time >= 4.1 and time < 5.7)
		var backpedal := time >= 4.1
		status.text = "IDLE" if not moving else ("BACKPEDAL" if backpedal else "WALK")
		status.text += "   |   Same textures / 1.7x game size"
		for i in range(8):
			var actor = actors[i]
			actor.state.angle = PI/2 if i%2 else 0.0
			actor.state.dir = Vector2.LEFT if backpedal else Vector2.RIGHT
			actor.advance_visual(1.0/30,moving)
			actor.sync_visual()
			previous[i].queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		var image := root.get_texture().get_image()
		assert(image.save_png(RAW+"%03d.png" % frame) == OK)
		if frame in [25,62,94,145,180]:
			assert(image.save_png(OUT+"pose-%03d.png" % frame) == OK)
	stage.free()
	root.size = Vector2i(1120,800)
	root.content_scale_size = root.size
	var game = load("res://scenes/game/main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	preload("res://tests/helpers/battle.gd").passive_opponents(game)
	game.assign_character(0,0)
	game.assign_character(1,7)
	preload("res://tests/helpers/battle.gd").start(game,20)
	for i in range(2):
		var actor = game.players[i]
		actor.state.pos = Vector2(350+i*380,430)
		actor.state.angle = 0.0 if i == 0 else PI
		actor.state.dir = Vector2.RIGHT if i == 0 else Vector2.LEFT
		actor.update_weapon_art()
		actor.advance_visual(.17,true)
		actor.sync_visual()
	game.hud.refresh(game.players,game.remaining,game.paused,game.result,game.scores,game.phase)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(OUT+"battle.png") == OK)
	game.free()
	print("PASS: 210 frames / 8 characters / before-after idle, walk, stop and backpedal / armed battle render")
	quit()
