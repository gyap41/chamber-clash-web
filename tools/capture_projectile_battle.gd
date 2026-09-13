extends SceneTree
const OUT="res://docs/art/reviews/projectile-effects-2026-09-13/"
const RAW="res://.local/projectile-battle-frames/"
func _initialize() -> void:call_deferred("run")
func run() -> void:
	DirAccess.make_dir_recursive_absolute(RAW)
	root.size=Vector2i(1120,800);root.content_scale_size=root.size
	var game=load("res://scenes/game/main.tscn").instantiate();root.add_child(game)
	game.set_physics_process(false)
	preload("res://tests/helpers/battle.gd").passive_opponents(game)
	game.assign_character(0,0);game.assign_character(1,7)
	preload("res://tests/helpers/battle.gd").start(game,37)
	game.players[1].inventory=[game.Weapons.new_inventory_entry(27)]
	game.players[1].state.gun=0
	game.command_source=func(index, _dt): return game.Command.idle(0 if index==0 else PI)
	for i in range(2):
		var p=game.players[i];p.state.pos=Vector2(300+i*500,260);p.state.angle=0 if i==0 else PI
		p.update_weapon_art();p.sync_visual()
	var peak:=0
	for frame in range(48):
		for i in range(2):
			var p=game.players[i]
			if p.weapon().clip==0:p.start_reload()
			else:game.fire(i)
		game._physics_process(.05)
		peak=maxi(peak,game.shots.size())
		await process_frame;await RenderingServer.frame_post_draw
		var shot=root.get_texture().get_image()
		assert(shot.save_png(RAW+"%03d.png"%frame)==OK)
		if frame==30:assert(shot.save_png(OUT+"battle.png")==OK)
	print("PASS: battle firing/reload/flight rendered; peak live projectiles=",peak)
	quit()
