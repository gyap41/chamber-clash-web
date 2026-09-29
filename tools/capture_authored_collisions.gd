extends SceneTree
# Collision review for the authored room trial: each room fitted to the screen with collision drawn over it.
# Red = placement collision, orange = invisible blocks, blue = walls, yellow outline = drawn picture of pieces WITHOUT collision that are
# not flat floor decals (candidates for missing collision). Also prints a table of every placement.
# Run: Godot --path . --script res://tools/capture_authored_collisions.gd --quit-after 3000
const OUT := "res://docs/art/production/authored-rooms/collisions/"
const Authored = preload("res://scripts/world/authored_rooms.gd")

class Overlay extends Node2D:
	var field
	func _draw() -> void:
		for wall in field.walls: draw_rect(wall,Color(.2,.5,1,.45))
		for p in field.placements:
			var visual := Rect2(p.position+p.visual_rect.position,p.visual_rect.size)
			if p.placement_id.begins_with("authored_block_"):
				draw_rect(Rect2(p.position+p.collision.position,p.collision.size),Color(1,.45,0,.55))
			elif p.collision != Rect2():
				draw_rect(Rect2(p.position+p.collision.position,p.collision.size),Color(1,.1,.1,.55))
				draw_rect(visual,Color(1,.3,.3,.9),false,1.0)
			elif not p.floor_decal:
				draw_rect(visual,Color(1,.9,.1,.9),false,2.0)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	root.size = Vector2i(1120,800)
	root.content_scale_size = root.size
	for i in range(Authored.ORDER.size()):
		var id: String = Authored.ORDER[i]
		var game = load("res://scenes/game/authored_rooms_preview.tscn").instantiate()
		game.start_room = id
		root.add_child(game)
		await process_frame
		game.set_physics_process(false)
		game.start_room = id
		game.start_exploration(1)
		game.set_physics_process(false)
		game.get_node("HUD").visible = false
		game.players[0].visible = false
		var overlay := Overlay.new()
		overlay.field = game.arena.runtime_definition
		overlay.z_index = 100
		game.arena.add_child(overlay)
		var camera: Camera2D = game.arena.get_node("CombatCamera")
		var bounds: Rect2 = game.arena.field_rect
		var zoom := minf(1120.0/bounds.size.x,800.0/bounds.size.y)
		camera.zoom = Vector2.ONE*zoom
		camera.position = bounds.get_center()-Vector2(560,400)/zoom
		camera.force_update_scroll()
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		var image: Image = root.get_texture().get_image()
		assert(image.save_png(ProjectSettings.globalize_path(OUT+"%02d-%s.png" % [i+1,id])) == OK)
		for p in overlay.field.placements:
			var kind := "COLLIDE" if p.collision != Rect2() else ("floor" if p.floor_decal else ("overlay" if p.surface_overlay else "NO-COLLISION"))
			print("%s\t%s\t%s\tvisual=%s\tcollision=%s" % [id,p.placement_id,kind,p.visual_rect.size.round(),p.collision.size.round()])
		game.queue_free()
		await process_frame
	print("PASS: collisions captured")
	quit()
