extends SceneTree
var OUT = "res://docs/archive/2026-09-12/rina-chibi/"
func _initialize() -> void:
	if "--twohead" in OS.get_cmdline_user_args(): OUT = "res://docs/archive/2026-09-12/rina-twohead/"
	call_deferred("run")
func capture(label: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(OUT+label+".png") == OK)
func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	root.size = Vector2i(1120,800)
	var game = load("res://scenes/game/main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	preload("res://tests/helpers/battle.gd").passive_opponents(game)
	game.assign_character(0,0)
	game.assign_character(1,3)
	preload("res://tests/helpers/battle.gd").start(game,20)
	var p = game.players[0]
	p.inventory = [p.Weapons.new_inventory_entry(20)]
	p.state.gun = 0
	p.update_weapon_art()
	p.state.pos = Vector2(370,300)
	game.players[1].state.pos = Vector2(860,280)
	game.players[1].sync_visual()
	var anim = p.get_node("Animation")
	for direction in [Vector2.DOWN,Vector2.UP,Vector2.LEFT,Vector2.RIGHT]:
		var label: String = "down" if direction.y > 0 else ("up" if direction.y < 0 else ("left" if direction.x < 0 else "right"))
		p.state.angle = direction.angle()
		p.state.dir = direction
		anim.moving = false
		p.sync_visual()
		game.hud.refresh(game.players,game.remaining,game.paused,game.result,game.scores,game.phase)
		await capture("idle-"+label)
		anim.moving = true
		for frame in range(6):
			anim.move_phase = float(frame)
			p.sync_visual()
			await capture("move-"+label+"-%02d" % frame)
		anim.moving = false
		for frame in range(6):
			p.state.roll = p.dodge_duration*(1.0-(frame+.1)/6.0)
			p.sync_visual()
			await capture("roll-"+label+"-%02d" % frame)
		p.state.roll = 0.0
		p.state.inv = 0.0
	# Aim remains independent of vertical travel.
	p.state.angle = .3
	p.state.dir = Vector2.UP
	anim.moving = true
	anim.move_phase = 2.0
	p.sync_visual()
	await capture("strafe-up-aim-right")
	anim.moving = false
	game.fire(0)
	p.sync_visual()
	game.hud.refresh(game.players,game.remaining,game.paused,game.result,game.scores,game.phase)
	await capture("shooting")
	p.start_reload()
	p.state.reload *= .5
	anim.muzzle = 0
	p.sync_visual()
	await capture("reload")
	print("PASS: Chibi four-direction movement/roll and shooting/reload captures")
	game.queue_free()
	quit()
