extends SceneTree
const Visual = preload("res://scripts/visuals/remaining_machine_visual.gd")
const Names := ["走り番機","浮遊散弾機","破砕番機","環砲機"]
class Sample extends Node2D:
	var view: Dictionary
	func _draw() -> void:
		Visual.paint(self,view)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size = Vector2i(1120,760)
	root.content_scale_size = root.size
	var samples: Array[Sample] = []
	var labels: Array[Label] = []
	var backdrop := ColorRect.new()
	backdrop.color = Color("292d2e")
	backdrop.size = Vector2(1120,760)
	root.add_child(backdrop)
	for row in range(4):
		var id: String = Visual.IDS[row]
		for col in range(5):
			var actor := Sample.new()
			actor.view = {"enemy_id":id,"alive":true,"phase":"chase","remaining":.5,"windup":1.0,"recovery":1.0,"shot_interval":.5,"motion":1.0,"angle":[PI/2,-PI/2,0,PI,0][col],"gait":0.0,"visual_time":0.0}
			actor.position = Vector2(100+col*220,145+row*180)
			actor.scale = Vector2.ONE*(2.4 if col == 4 else 1.2)
			root.add_child(actor)
			samples.append(actor)
			var label := Label.new()
			label.text = Names[row]+" / "+["前","後","右","左","拡大"][col]
			label.position = Vector2(20+col*220,152+row*180)
			label.add_theme_font_size_override("font_size",15)
			root.add_child(label)
			labels.append(label)
	var folder := "res://.local/remaining-machine-frames"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	for frame in range(150):
		var time := frame/15.0
		for actor in samples:
			actor.view.gait = time*6
			actor.view.visual_time = time
			actor.view.phase = "chase" if time < 2 else ("windup" if time < 3 else ("spit" if time < 4 else ("recover" if time < 5 else "grace")))
			actor.view.motion = 1.0 if time < 2 else 0.0
			actor.view.remaining = 3-time if time >= 2 and time < 3 else (.5-fposmod(time,.5) if time < 4 else maxf(0,5-time))
			if actor.view.enemy_id == "ram_sentry" and time >= 3 and time < 4:
				actor.view.phase = "dash"
				actor.view.motion = 1.0
			if time >= 6 and time < 7: actor.view.hit = (1.0-fposmod(time,.3)/.3)*.7
			else: actor.view.hit = 0.0
			if time >= 8: actor.view.death_progress = clampf((time-8)/.85,0,1)
			actor.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		var screenshot := root.get_texture().get_image()
		assert(screenshot.save_png(folder+"/%03d.png" % frame) == OK)
		if frame in [0,37,47,64,123]:
			assert(screenshot.save_png("res://docs/art/production/enemy-animation-v2/machines-%03d.png" % frame) == OK)
	print("PASS: 4 machine cutout rigs, 4 directions, movement/attack/recovery/hit/death review frames")
	quit()
