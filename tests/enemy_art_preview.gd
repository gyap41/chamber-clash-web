extends SceneTree
## Candidate-only art review. Does not change combat renderers or timings.
class Gallery extends Node2D:
	var sheets: Array[Texture2D] = []
	func _draw() -> void:
		var font := ThemeDB.fallback_font
		for enemy in range(2):
			var left := 155.0 + enemy * 490.0
			draw_string(font, Vector2(left, 230), ["SENTRY / candidate", "FIRE-POUCH LIZARD / candidate"][enemy], HORIZONTAL_ALIGNMENT_LEFT, -1, 18)
			for row in range(3):
				draw_string(font, Vector2(left - 65, 305 + row * 100), ["Idle", "Windup", "Attack"][row], HORIZONTAL_ALIGNMENT_LEFT, -1, 14)
				for col in range(3):
					var center := Vector2(left + 50 + col * 120, 280 + row * 100)
					var factor := 0.14 if enemy == 0 else 0.15
					var size := Vector2.ONE * 418 * factor
					draw_texture_rect_region(sheets[enemy], Rect2(center, size), Rect2(col * 418, row * 418, 418, 418))
					if row == 0:
						draw_string(font, center + Vector2(0, -10), ["Front", "Back", "Right"][col], HORIZONTAL_ALIGNMENT_LEFT, -1, 14)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.size = Vector2i(1120, 800)
	var game = load("res://scenes/game/exploration.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.set_pause_reason("focus", false)
	game.players[0].state.pos = Vector2(490, 400)
	game.players[0].sync_visual()
	var layer := CanvasLayer.new()
	root.add_child(layer)
	var gallery := Gallery.new()
	for file in ["sentry-sheet-v1.png", "lizard-sheet-v1.png"]:
		var picture := Image.load_from_file("res://assets/first-workshop/enemies/" + file)
		assert(picture != null and picture.get_size() == Vector2i(1254, 1254))
		gallery.sheets.append(ImageTexture.create_from_image(picture))
	layer.add_child(gallery)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://.local/enemy-art-preview.png") == OK)
	print("enemy_art_preview: captured candidate sheets at constant scale")
	game.queue_free()
	layer.queue_free()
	await process_frame
	quit()
