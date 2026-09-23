extends SceneTree
const Surface = preload("res://scripts/world/connected_wall_surface.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	# No edge may face another filled cell across a join, even after subdivision.
	var layouts: Array = [
		[Rect2(0,0,100,24),Rect2(76,24,24,80)],
		[Rect2(0,0,100,24),Rect2(38,24,24,80)],
		[Rect2(0,0,100,24),Rect2(38,-40,24,104)],
		[Rect2(0,0,50,24),Rect2(50,0,50,24),Rect2(38,24,24,80)]]
	for layout in layouts:
		var rects: Array[Rect2] = []
		rects.assign(layout)
		var edges := Surface.outline(rects)
		assert(not edges.is_empty())
		for edge in edges:
			var outside: Vector2 = edge.rect.get_center()+edge.normal*1.1
			for rect in rects: assert(not rect.has_point(outside))
		var reversed := rects.duplicate()
		reversed.reverse()
		var other := Surface.outline(reversed)
		assert(edges == other)
	var invalid = preload("res://data/stage_themes/workshop_showcase.tres").duplicate(true)
	invalid.wall_edge = null
	assert(not invalid.validation_errors().is_empty())
	var game = load("res://scenes/game/exploration.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	assert(game.arena.has_node("ConnectedWallSurface"))
	var surface = game.arena.get_node("ConnectedWallSurface")
	var return_point := Vector2(1008,220)
	assert(surface.faces.any(func(rect): return rect.has_point(return_point)))
	assert(not surface.tops.any(func(rect): return rect.has_point(return_point)))
	for point in [Vector2(112,90),Vector2(1008,90)]:
		assert(surface.tops.any(func(rect): return rect.has_point(point)))
		assert(not surface.faces.any(func(rect): return rect.has_point(point)))
	for face in surface.faces:
		for top in surface.tops: assert(not top.intersection(face).has_area())
	var original = game.arena.runtime_definition
	var walls: Array[Rect2] = original.walls.duplicate()
	assert(game.arena.get_node("ConnectedWallSurface").boundaries.size() > 0)
	var legacy = preload("res://data/fields/workshop_annex.tres").duplicate(true)
	legacy.theme = legacy.theme.duplicate(true)
	legacy.theme.connected_walls = false
	assert(game.switch_field(legacy).is_empty())
	assert(not game.arena.has_node("ConnectedWallSurface"))
	assert(game.switch_field(original).is_empty())
	assert(game.arena.runtime_definition.walls == walls)
	assert(game.arena.get_node("ConnectedWallSurface").tops.size() > 0)
	game.queue_free()
	await process_frame
	print("PASS: L/T/cross union has no internal rims, subdivision/order stability, theme cleanup and unchanged collisions")
	quit()
