extends Node2D
@export var speed: float = 420.0
@export var lifetime: float = 2.8
@export var radius: float = 4.0
@export var damage: float = 1.0
@export var ricochets: int = 2
var state: Dictionary
func launch(player, index: int) -> void:
	var p = player.state
	state = {"pos":p.pos+Vector2.from_angle(p.angle)*24,"velocity":Vector2.from_angle(p.angle)*speed,"owner":index,"life":lifetime,"bounce":ricochets if p.gun == 1 else 0,"dead":false}
	position = state.pos
	$Visual.modulate = Color("ffe1a0") if index == 0 else Color("a2dfff")
func step(dt: float, arena, enemy) -> void:
	var b = state
	var bounds: Rect2 = arena.projectile_bounds
	b.life -= dt
	var steps := maxi(1,ceili(b.velocity.length()*dt/5))
	for n in range(steps):
		if b.dead: break
		var previous: Vector2 = b.pos
		b.pos += b.velocity*dt/steps
		if b.pos.x < bounds.position.x or b.pos.x > bounds.end.x or b.pos.y < bounds.position.y or b.pos.y > bounds.end.y or arena.solid(b.pos,radius):
			if b.bounce > 0:
				b.bounce -= 1
				if b.pos.x < bounds.position.x or b.pos.x > bounds.end.x or arena.solid(Vector2(b.pos.x,previous.y),radius): b.velocity.x *= -1
				else: b.velocity.y *= -1
				b.pos = previous
			else: b.dead = true
		elif b.pos.distance_to(enemy.state.pos) < enemy.radius + radius:
			enemy.hurt(damage)
			b.dead = true
	position = b.pos
