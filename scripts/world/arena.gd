extends Node2D
const Definition = preload("res://scripts/world/field_definition.gd")
const Builder = preload("res://scripts/world/field_builder.gd")
@export var definition: Definition
var runtime_definition: Definition
var field_rect: Rect2
var fighter_bounds: Rect2
var projectile_bounds: Rect2
func _ready() -> void:
	var errors := configure_field(definition,$Players.get_child_count())
	assert(errors.is_empty(),"; ".join(errors))
func configure_field(source: Definition, participant_count: int = 0, radius: float = 14.0) -> PackedStringArray:
	var errors := Builder.apply(self,source,participant_count,radius)
	if errors.is_empty(): definition = source
	return errors
func solid(pos: Vector2, radius: float, projectile: bool = false) -> bool:
	if runtime_definition != null:
		if not runtime_definition.floor_contains(pos): return true
		for placement in runtime_definition.placements:
			var local: Rect2 = placement.projectile_rect() if projectile else placement.collision
			if not local.has_area(): continue
			var rect := Rect2(placement.position+local.position,local.size)
			if pos.distance_to(pos.clamp(rect.position,rect.end)) < radius: return true
	for node in $Walls.get_children():
		var wall: Rect2 = node.collision_rect()
		var closest := Vector2(clampf(pos.x,wall.position.x,wall.end.x),clampf(pos.y,wall.position.y,wall.end.y))
		if pos.distance_to(closest) < radius:
			return true
	return false

func projectile_solid(pos: Vector2, radius: float) -> bool:
	return solid(pos,radius,true)

func projectile_line_blocked(from: Vector2, to: Vector2, radius: float = 2.0) -> bool:
	# Analytic cover rays are also used by pathfinding: don't sample every prop at every pixel.
	if runtime_definition != null:
		if runtime_definition.constrain_to_floor:
			var steps := maxi(1,ceili(from.distance_to(to)/4.0))
			for index in range(steps+1):
				if not runtime_definition.floor_contains(from.lerp(to,float(index)/steps)): return true
		for placement in runtime_definition.placements:
			var local: Rect2 = placement.projectile_rect()
			if local.has_area() and segment_hits_rect(from,to,Rect2(placement.position+local.position,local.size).grow(radius)): return true
	for wall in $Walls.get_children():
		if segment_hits_rect(from,to,wall.collision_rect().grow(radius)): return true
	return false

static func segment_hits_rect(from: Vector2, to: Vector2, rect: Rect2) -> bool:
	var delta := to-from
	var first := 0.0
	var last := 1.0
	for axis in range(2):
		if absf(delta[axis]) < .00001:
			if from[axis] < rect.position[axis] or from[axis] > rect.end[axis]: return false
		else:
			var a: float = (rect.position[axis]-from[axis])/delta[axis]
			var b: float = (rect.end[axis]-from[axis])/delta[axis]
			first = maxf(first,minf(a,b))
			last = minf(last,maxf(a,b))
			if first > last: return false
	return true

func move_fighter(p: Dictionary, delta: Vector2, radius: float = 14.0) -> void:
	var steps := maxi(1,ceili(delta.length()/5))
	for n in range(steps):
		var dest: Vector2 = p.pos + Vector2(delta.x/steps,0)
		dest.x = clampf(dest.x,fighter_bounds.position.x,fighter_bounds.end.x)
		if not solid(dest,radius): p.pos = dest
		dest = p.pos + Vector2(0,delta.y/steps)
		dest.y = clampf(dest.y,fighter_bounds.position.y,fighter_bounds.end.y)
		if not solid(dest,radius): p.pos = dest


# Segment sampling matches legacy lineBlocked; checks the editable wall geometry.
func line_blocked(from: Vector2, to: Vector2) -> bool:
	var steps := ceili(from.distance_to(to)/8.0)
	for i in range(1,steps):
		if solid(from.lerp(to,float(i)/steps),2.0): return true
	return false

func safe_rect(inset: float, padding: Vector2 = Vector2(25,25)) -> Rect2:
	var margin := Vector2(inset,inset*.58)+padding
	margin = margin.min(field_rect.size*.49)
	return Rect2(field_rect.position+margin,field_rect.size-2*margin)
func spawn_position(slot: int) -> Vector2:
	var markers := $Spawns.get_children()
	assert(slot >= 0 and slot < markers.size(), "Field needs a spawn for every participant")
	return to_local(markers[slot].global_position)
func apply_hazards(player, inset: float) -> void:
	var safe := safe_rect(inset)
	var pos: Vector2 = player.state.pos
	if inset > 0 and (pos.x < safe.position.x or pos.x > safe.end.x or pos.y < safe.position.y or pos.y > safe.end.y):
		player.hurt(.16,-1,true,{"kind":"danger_zone"})
