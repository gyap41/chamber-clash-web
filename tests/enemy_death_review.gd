extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	root.size = Vector2i(1120,800)
	var background := ColorRect.new()
	background.color = Color("353932")
	background.size = Vector2(1120,800)
	root.add_child(background)
	for row in range(2):
		for col in range(5):
			var effect = preload("res://scripts/visuals/enemy_death.gd").new()
			effect.snapshot = {"alive":false,"angle":0.0,"phase":"recover","remaining":1.0,
				"recovery":1.4,"windup":.8,"reach":62,"hp_ratio":0.0}
			effect.organic = row == 1
			effect.elapsed = [.08,.35,.6,.8,1.05][col]
			effect.position = Vector2(120+col*220,260+row*250)
			root.add_child(effect)
			var label := Label.new()
			label.text = ("Lizard " if row else "Sentry ")+str(effect.elapsed)+"s"
			label.position = effect.position+Vector2(-45,25)
			root.add_child(label)
	for i in range(3): await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://.local/enemy-death-review.png") == OK)
	quit()
