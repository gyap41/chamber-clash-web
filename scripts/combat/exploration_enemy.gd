extends "res://scripts/combat/player.gd"
# Combat adapter only: no duel AI, purchases, equipment build or enemy rally healing.
const Spec = preload("res://scripts/catalog/exploration_enemy_catalog.gd")
const Navigation = preload("res://scripts/ai/cpu_navigation.gd")
var spec: Dictionary = Spec.SENTRY
var attack_phase := "grace"
var attack_time := 1.0
var attack_angle := 0.0
var route: Array = []
var route_time := 0.0

func prepare(spawn: Vector2) -> void:
	max_hp = spec.hp
	move_speed = spec.speed
	radius = spec.radius
	initial_pulses = 0
	attack_time = spec.entry_grace
	reset(spawn)

func recover_rally(_dealt: float) -> void:
	pass

func advance_visual(_dt: float, _moving: bool) -> void:
	pass

func sync_visual() -> void:
	position = state.pos
	for child in [$Sprite,$Animation,$Aim,$Identity,$Weapon,$Slash]: child.hide()
	queue_redraw()

func step(dt: float, i: int, enemy, arena, _mouse_shooting: bool = false, _ai: Dictionary = {}) -> bool:
	var command := preload("res://scripts/combat/combat_command.gd").idle(state.angle)
	if enemy == null or enemy.state.hp <= 0: return false
	attack_time = maxf(0.0,attack_time-dt)
	var delta: Vector2 = enemy.state.pos-state.pos
	if attack_phase == "windup":
		command.angle = attack_angle
		if attack_time <= 0:
			# Aim locks when the tell starts; stepping away or behind a wall avoids it.
			if delta.length() <= spec.range and absf(angle_difference(attack_angle,delta.angle())) <= PI/3 and not arena.line_blocked(state.pos,enemy.state.pos):
				enemy.hurt(spec.damage,-1,false,{"kind":"enemy_melee","enemy":participant_id},self)
			ring_requested.emit(state.pos,Color("ffb65c"),spec.range)
			attack_phase = "recover"
			attack_time = spec.recovery
	elif attack_time <= 0:
		attack_phase = "chase"
		command.angle = delta.angle()
		if delta.length() <= spec.range-8 and not arena.line_blocked(state.pos,enemy.state.pos):
			attack_phase = "windup"
			attack_time = spec.windup
			attack_angle = delta.angle()
		elif Navigation.segment_clear(arena,state.pos,enemy.state.pos):
			command.dx = delta.normalized().x
			command.dy = delta.normalized().y
			route.clear()
		else:
			route_time -= dt
			if route_time <= 0:
				route = Navigation.combat_path(arena,state.pos,enemy.state.pos,Vector2(0,spec.range-8),16384)
				route_time = .65
			while not route.is_empty() and state.pos.distance_to(route[0]) < 6: route.pop_front()
			if not route.is_empty():
				var axis: Vector2 = (route[0]-state.pos).normalized()
				command.dx = axis.x
				command.dy = axis.y
	super.step(dt,i,enemy,arena,false,command)
	return false

func _draw() -> void:
	if state.is_empty() or state.hp <= 0: return
	if attack_phase == "windup":
		var points := PackedVector2Array([Vector2.ZERO])
		for n in range(25): points.append(Vector2.from_angle(attack_angle-PI/3+n*PI/36)*float(spec.range))
		draw_colored_polygon(points,Color(1.0,.42,.12,.22))
		draw_arc(Vector2.ZERO,spec.range,attack_angle-PI/3,attack_angle+PI/3,24,Color("ffb65c"),2)
	draw_set_transform(Vector2(0,5),0,Vector2(1,.45))
	draw_circle(Vector2.ZERO,19,Color(0,0,0,.4))
	draw_set_transform(Vector2.ZERO)
	draw_rect(Rect2(-15,-23,30,30),Color("343d41"))
	draw_rect(Rect2(-13,-23,26,22),Color("b79a68"))
	draw_rect(Rect2(-10,-21,20,7),Color("d7bf89"))
	draw_circle(Vector2.from_angle(state.angle)*8+Vector2(0,-10),4,Color("ff884d"))
	draw_line(Vector2(-12,9),Vector2(12,9),Color("3b2924"),3)
	draw_line(Vector2(-12,9),Vector2(-12+24*state.hp/state.max_hp,9),Color("e69258"),3)
