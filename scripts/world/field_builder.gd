extends RefCounted
const Definition = preload("res://scripts/world/field_definition.gd")
const Wall = preload("res://scenes/world/wall.tscn")
const Prop = preload("res://scripts/world/stage_prop.gd")

# Validate a private snapshot before replacing any live geometry. Actors and inventory
# are deliberately outside this builder; their transition policy belongs to the caller.
static func apply(arena, source: Definition, participant_count: int = 0, radius: float = 14.0) -> PackedStringArray:
	if source == null: return PackedStringArray(["Field definition is required"])
	var definition: Definition = source.duplicate(true)
	var errors := definition.validation_errors(participant_count,radius)
	if not errors.is_empty(): return errors
	if arena.has_node("ConnectedWallSurface"):
		var old_surface = arena.get_node("ConnectedWallSurface")
		arena.remove_child(old_surface)
		old_surface.queue_free()
	clear_children(arena.get_node("Walls"))
	clear_children(arena.get_node("Spawns"))
	clear_children(arena.get_node("Supplies/Spawns"))
	for layer in ["StageBackground","StageForeground"]:
		if not arena.has_node(layer):
			var container := Node2D.new()
			container.name = layer
			arena.add_child(container)
			if layer == "StageBackground": arena.move_child(container,arena.get_node("Players").get_index())
		clear_children(arena.get_node(layer))
	arena.field_rect = definition.field_rect
	arena.fighter_bounds = definition.fighter_bounds
	arena.projectile_bounds = definition.projectile_bounds
	var depth: bool = definition.theme != null and definition.theme.depth_sort
	arena.y_sort_enabled = depth
	arena.get_node("Players").y_sort_enabled = depth
	arena.get_node("StageBackground").y_sort_enabled = depth
	arena.get_node("Floor").z_index = -20 if depth else 0
	arena.get_node("Walls").z_index = -10 if depth else 0
	arena.get_node("StageForeground").z_index = 5 if depth else 0
	for layer in ["Effects","Wells","Projectiles","CombatVisuals","DangerZone"]:
		if arena.has_node(layer): arena.get_node(layer).z_index = 10 if depth else 0
	var bounds := definition.field_rect
	arena.get_node("Floor").polygon = PackedVector2Array([bounds.position,Vector2(bounds.end.x,bounds.position.y),bounds.end,Vector2(bounds.position.x,bounds.end.y)])
	arena.get_node("Floor").color = definition.floor_color
	for i in range(definition.walls.size()):
		var wall = Wall.instantiate()
		wall.name = "Wall%d" % (i+1)
		wall.position = definition.walls[i].position
		wall.size = definition.walls[i].size
		wall.surface_texture = definition.wall_textures.get(i,null)
		wall.face_texture = definition.wall_face_textures.get(i,null)
		if definition.theme != null: wall.apply_theme(definition.theme)
		if not definition.wall_ids.is_empty():
			var role: String = definition.wall_materials.get(definition.wall_ids[i],"cover")
			if role != "cover": wall.surface_texture = definition.theme.wall_top
			if role == "face": wall.face_texture = definition.theme.wall_face
		arena.get_node("Walls").add_child(wall)
	for wall in arena.get_node("Walls").get_children():
		wall.connect_faces(arena.get_node("Walls").get_children())
	if definition.theme != null and definition.theme.connected_walls:
		var surface := preload("res://scripts/world/connected_wall_surface.gd").new()
		surface.name = "ConnectedWallSurface"
		surface.z_index = -9 if depth else 0
		arena.add_child(surface)
		arena.move_child(surface,arena.get_node("Players").get_index())
		surface.configure(arena.get_node("Walls").get_children(),definition.theme)
	for placement in definition.placements:
		if placement.floor_decal: continue # Draw below actors, clipped to floor regions.
		var prop := Prop.new()
		prop.definition = placement
		if placement.surface_overlay: prop.z_index = -8
		arena.get_node("StageBackground" if placement.layer == 0 else "StageForeground").add_child(prop)
	for i in range(definition.spawns.size()):
		marker(arena.get_node("Spawns"),"P%d" % (i+1),definition.spawns[i])
	for group in definition.supply_points:
		var container := Node2D.new()
		container.name = group
		arena.get_node("Supplies/Spawns").add_child(container)
		var points: PackedVector2Array = definition.supply_points[group]
		for i in range(points.size()): marker(container,"Point%d" % (i+1),points[i])
	arena.runtime_definition = definition
	if arena.has_node("Floor/WorkshopArt"): arena.get_node("Floor/WorkshopArt").queue_redraw()
	arena.get_node("DangerZone").queue_redraw()
	return errors

static func marker(parent: Node, name: String, position: Vector2) -> void:
	var point := Marker2D.new()
	point.name = name
	point.position = position
	parent.add_child(point)

static func clear_children(parent: Node) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()
