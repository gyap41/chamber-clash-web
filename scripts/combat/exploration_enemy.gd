extends "res://scripts/combat/player.gd"
# Combat adapter only: no duel AI, purchases, equipment build or enemy rally healing.
const Spec = preload("res://scripts/catalog/exploration_enemy_catalog.gd")
const SentryVisual = preload("res://scripts/visuals/sentry_visual.gd")
const Navigation = preload("res://scripts/ai/cpu_navigation.gd")
var spec: Dictionary = Spec.SENTRY
var attack_phase := "grace"
var attack_time := 1.0
var attack_angle := 0.0
var route: Array = []
var route_time := 0.0
var gait_phase := 0.0
var motion_weight := 0.0
var visual_time := 0.0
var previous_visual_position := Vector2.ZERO

func prepare(spawn: Vector2) -> void:
	max_hp = spec.hp
	move_speed = spec.speed
	radius = spec.radius
	initial_pulses = 0
	attack_time = spec.entry_grace
	gait_phase = 0.0
	motion_weight = 0.0
	visual_time = 0.0
	previous_visual_position = spawn
	reset(spawn)

func recover_rally(_dealt: float) -> void:
	pass

func hurt(amount: float, volley: int = -1, hazard: bool = false, origin: Dictionary = {}, attacker = null) -> bool:
	var alive: bool = state.hp > 0
	var applied := super.hurt(amount,volley,hazard,origin,attacker)
	if applied and alive and state.hp <= 0:
		sound_requested.emit(spec.death_sound,0)
		var remains := preload("res://scripts/visuals/enemy_death.gd").new()
		remains.snapshot = enemy_visual_snapshot()
		for connection in sound_requested.get_connections():
			remains.sound_requested.connect(connection.callable)
		remains.organic = spec.id not in ["workshop_sentry","furnace_warden"]
		remains.position = state.pos
		remains.add_to_group("enemy_death_visuals")
		get_parent().add_child(remains)
	return applied

func advance_visual(dt: float, _moving: bool) -> void:
	var distance: float = state.pos.distance_to(previous_visual_position)
	previous_visual_position = state.pos
	visual_time += dt
	# Actual displacement drives feet; pushing against a wall does not walk in place.
	var walking := distance > .01 and distance < 50 and attack_phase == "chase"
	if walking: gait_phase += distance / 38.0 * TAU
	motion_weight = move_toward(motion_weight,1.0 if walking else 0.0,dt*10)

func sync_visual() -> void:
	position = state.pos
	for child in [$Sprite,$Animation,$Aim,$Identity,$Weapon,$Slash]: child.hide()
	queue_redraw()

func step(dt: float, i: int, enemy, arena, _mouse_shooting: bool = false, _ai: Dictionary = {}) -> bool:
	var command := preload("res://scripts/combat/combat_command.gd").idle(state.angle)
	if state.hp <= 0 or enemy == null or enemy.state.hp <= 0: return false
	attack_time = maxf(0.0,attack_time-dt)
	var delta: Vector2 = enemy.state.pos-state.pos
	if attack_phase == "windup":
		command.angle = attack_angle
		if attack_time <= 0:
			sound_requested.emit("sentry_swing",0)
			# Aim locks when the tell starts; stepping away or behind a wall avoids it.
			if delta.length() <= spec.range and absf(angle_difference(attack_angle,delta.angle())) <= PI/3 and not arena.line_blocked(state.pos,enemy.state.pos):
				enemy.hurt(spec.damage,-1,false,{"kind":"enemy_melee","enemy":participant_id},self)
			attack_phase = "recover"
			attack_time = spec.recovery
	elif attack_time <= 0:
		attack_phase = "chase"
		command.angle = delta.angle()
		if delta.length() <= spec.range-8 and not arena.line_blocked(state.pos,enemy.state.pos):
			attack_phase = "windup"
			attack_time = spec.windup
			attack_angle = delta.angle()
			sound_requested.emit("sentry_windup",0)
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
	return move_with_command(dt,i,enemy,arena,command)

func move_with_command(dt: float, i: int, enemy, arena, command: Dictionary) -> bool:
	super.step(dt,i,enemy,arena,false,command)
	return false

# Values only: rendering cannot advance attacks or modify the combat state.
func enemy_visual_snapshot() -> Dictionary:
	return {"enemy_id":spec.id,"alive":not state.is_empty() and state.hp > 0,
		"phase":attack_phase,"remaining":attack_time,"windup":float(spec.windup),
		"gait":gait_phase,"motion":motion_weight,"visual_time":visual_time,
		"hit":clampf(float(state.get("inv",0))/.22,0,1),
		"recovery":float(spec.recovery),"reach":float(spec.range),
		"angle":attack_angle if attack_phase in ["windup","recover"] else float(state.get("angle",0)),
		"hp_ratio":float(state.get("hp",0))/maxf(1.0,float(state.get("max_hp",1)))}

func _draw() -> void:
	SentryVisual.paint(self,enemy_visual_snapshot())
