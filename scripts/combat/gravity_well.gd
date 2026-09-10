extends Node2D
@export var duration := 3.2
@export var pull_radius := 155.0
@export var pull_speed := 125.0
@export var damage_radius := 72.0
@export var tick_interval := .35
@export var tick_damage := .65
@export var bullet_radius := 125.0
@export var absorb_radius := 15.0
@export var bullet_acceleration := 550.0
var state: Dictionary = {}
func launch(pos: Vector2, owner_index: int) -> void:
	position = pos
	state = {"owner":owner_index,"life":duration,"tick":0.0}
	$Identity.text = "P%d 重力場" % (owner_index+1)
func _ready() -> void:
	for entry in [["PullRing",pull_radius],["DamageRing",damage_radius],["Core",absorb_radius]]:
		var points := PackedVector2Array()
		for i in range(65): points.append(Vector2.from_angle(i*TAU/64)*entry[1])
		get_node(entry[0]).points = points
func step(dt: float, arena, players: Array, shots: Array) -> void:
	state.life -= dt
	state.tick -= dt
	var enemy = players[1-state.owner]
	var offset: Vector2 = position-enemy.state.pos
	var distance := offset.length()
	if distance < pull_radius and distance > 4.0 and enemy.state.roll <= 0:
		arena.move_fighter(enemy.state,offset/distance*pull_speed*dt,enemy.radius)
		enemy.sync_visual()
	if state.tick <= 0:
		state.tick = tick_interval
		if distance < damage_radius and not arena.line_blocked(position,enemy.state.pos): enemy.hurt(tick_damage)
	for shot in shots:
		var b: Dictionary = shot.state
		if b.dead or b.owner == state.owner: continue
		var toward: Vector2 = position-b.pos
		var d := toward.length()
		if d < bullet_radius:
			if d < absorb_radius: b.dead = true
			else: b.velocity += toward/d*bullet_acceleration*dt
	modulate.a = clampf(state.life/.3,.0,1.0)
