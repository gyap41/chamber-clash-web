extends SceneTree
class Board extends Node2D:
	const Sheet = preload("res://scripts/visuals/enemy_sheet_visual.gd")
	func _draw() -> void:
		draw_rect(Rect2(0,0,1120,800),Color("383c36"))
		var font := ThemeDB.fallback_font
		for r in range(8):
			var organic := r >= 4
			var direction: float = [PI/2,-PI/2,0,PI][r%4]
			draw_set_transform(Vector2.ZERO)
			draw_string(font,Vector2(10,100+r*85), ("Lizard " if organic else "Sentry ")+["front","back","right","left"][r%4],HORIZONTAL_ALIGNMENT_LEFT,-1,14)
			for c in range(8):
				var view := {"alive":true,"angle":direction,"phase":"chase","remaining":.1,
					"windup":.8,"recovery":1.4,"reach":62,"hp_ratio":1.0,"motion":1.0,"gait":c*TAU/4+.01}
				if c == 4: view.phase = "windup"
				if c == 5:
					view.phase = "spit" if organic else "recover"
					view.remaining = .1 if organic else 1.35
				if c == 6: view.phase = "grace"; view.hit = .7
				if c == 7: view.death_progress = .3
				# Child transform wrapper keeps the renderer's local draw resets contained.
				var renderer := Sample.new()
				renderer.view = view
				renderer.organic = organic
				renderer.position = Vector2(175+c*125,108+r*85)
				add_child.call_deferred(renderer)
		for c in range(8):
			draw_string(font,Vector2(145+c*125,22),["Walk A","Walk B","Walk C","Walk D","Windup","Attack","Hit","Down"][c],HORIZONTAL_ALIGNMENT_LEFT,-1,14)
class Sample extends Node2D:
	var view: Dictionary
	var organic: bool
	func _draw() -> void:
		preload("res://scripts/visuals/enemy_sheet_visual.gd").paint(self,view,organic)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	root.size = Vector2i(1120,800)
	root.add_child(Board.new())
	for i in range(5): await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://.local/enemy-animation-v2-review.png") == OK)
	quit()
