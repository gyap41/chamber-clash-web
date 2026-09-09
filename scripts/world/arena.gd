extends Node2D
@export var fighter_bounds := Rect2(60,82,1000,458)
# Legacy's wall-bounce check (game.js:113) is b.y<37||b.y>H-30 (H=600): top=37, bottom=570.
# Left/right (32 / W-32, W=1120) and bottom already matched; only the top was off by ~23px.
@export var projectile_bounds := Rect2(32,37,1056,533)
func solid(pos: Vector2, radius: float) -> bool:
	for node in $Walls.get_children():
		var wall: Rect2 = node.collision_rect()
		var closest := Vector2(clampf(pos.x,wall.position.x,wall.end.x),clampf(pos.y,wall.position.y,wall.end.y))
		if pos.distance_to(closest) < radius:
			return true
	return false

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
