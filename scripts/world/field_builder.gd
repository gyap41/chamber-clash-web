extends RefCounted
const Definition = preload("res://scripts/world/field_definition.gd")
const Wall = preload("res://scenes/world/wall.tscn")

# Validate a private snapshot before replacing any live geometry. Actors and inventory
# are deliberately outside this builder; their transition policy belongs to the caller.
static func apply(arena, source: Definition, participant_count: int = 0, radius: float = 14.0) -> PackedStringArray:
	if source == null: return PackedStringArray(["Field definition is required"])
	var definition: Definition = source.duplicate(true)
	var errors := definition.validation_errors(participant_count,radius)
	if not errors.is_empty(): return errors
	clear_children(arena.get_node("Walls"))
	clear_children(arena.get_node("Spawns"))
	clear_children(arena.get_node("Supplies/Spawns"))
	arena.field_rect = definition.field_rect
	arena.fighter_bounds = definition.fighter_bounds
	arena.projectile_bounds = definition.projectile_bounds
	var bounds := definition.field_rect
	arena.get_node("Floor").polygon = PackedVector2Array([bounds.position,Vector2(bounds.end.x,bounds.position.y),bounds.end,Vector2(bounds.position.x,bounds.end.y)])
	arena.get_node("Floor").color = definition.floor_color
	for i in range(definition.walls.size()):
		var wall = Wall.instantiate()
		wall.name = "Wall%d" % (i+1)
		wall.position = definition.walls[i].position
		wall.size = definition.walls[i].size
		arena.get_node("Walls").add_child(wall)
	for i in range(definition.spawns.size()):
		marker(arena.get_node("Spawns"),"P%d" % (i+1),definition.spawns[i])
	for group in definition.supply_points:
		var container := Node2D.new()
		container.name = group
		arena.get_node("Supplies/Spawns").add_child(container)
		var points: PackedVector2Array = definition.supply_points[group]
		for i in range(points.size()): marker(container,"Point%d" % (i+1),points[i])
	arena.runtime_definition = definition
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
