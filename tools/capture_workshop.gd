extends SceneTree
# Deterministic renderer for production-size review. No gameplay rules changed.
func _initialize() -> void:
	call_deferred("run")
func capture(label: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var folder := "res://docs/archive/2026-09-12/first-workshop"
	DirAccess.make_dir_recursive_absolute(folder)
	assert(root.get_texture().get_image().save_png(folder+"/"+label+".png") == OK)
func run() -> void:
	root.size = Vector2i(1120,800)
	var game = load("res://scenes/game/main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	preload("res://tests/helpers/battle.gd").passive_opponents(game)
	game.assign_character(0,0)
	game.assign_character(1,3)
	preload("res://tests/helpers/battle.gd").start(game,20)
	game.players[0].inventory = [game.players[0].Weapons.new_inventory_entry(20)]
	game.players[0].state.gun = 0
	game.players[0].update_weapon_art()
	game.players[0].state.pos = Vector2(370,300)
	game.players[1].state.pos = Vector2(860,280)
	game.players[0].sync_visual()
	game.players[1].sync_visual()
	game.hud.refresh(game.players,game.remaining,game.paused,game.result,game.scores,game.phase)
	await capture("01-environment")
	if "--motion" in OS.get_cmdline_user_args():
		var p = game.players[0]
		var anim = p.get_node("Animation")
		for i in range(4):
			anim.elapsed = i/3.0
			anim.moving = false
			p.sync_visual()
			await capture("idle-%02d" % i)
		for i in range(6):
			anim.move_phase = float(i)
			anim.moving = true
			p.sync_visual()
			await capture("move-%02d" % i)
		anim.moving = false
		p.state.dir = Vector2.RIGHT
		for i in range(6):
			p.state.roll = .26*(1.0-(i+.1)/6.0)
			p.sync_visual()
			await capture("roll-%02d" % i)
		p.state.roll = 0
		p.state.inv = 0
		p.sync_visual()
		game.fire(0)
		game.hud.refresh(game.players,game.remaining,game.paused,game.result,game.scores,game.phase)
		await capture("02-shooting")
		game._physics_process(.3)
		p.start_reload()
		p.state.reload *= .5
		anim.muzzle = 0
		p.sync_visual()
		game.hud.refresh(game.players,game.remaining,game.paused,game.result,game.scores,game.phase)
		await capture("03-reload")
		p.state.reload = 0
		p.finish_reload()
		p.weapon().reserve = 0
		var ammo = game.supplies.items.filter(func(item): return item.kind == "ammo")[0]
		ammo.age = 1.0
		p.state.pos = ammo.position-Vector2(45,0)
		p.sync_visual()
		game.hud.refresh(game.players,game.remaining,game.paused,game.result,game.scores,game.phase)
		ammo.refresh(game.players)
		await capture("04-resupply-before")
		p.state.pos = ammo.position
		p.sync_visual()
		assert(game.supplies.acquire(0,ammo))
		game.hud.refresh(game.players,game.remaining,game.paused,game.result,game.scores,game.phase)
		await capture("05-resupply-after")
	game.queue_free()
	quit()
