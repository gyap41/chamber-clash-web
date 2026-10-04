extends "res://scripts/combat/player.gd"
# Combat adapter only: no duel AI, purchases, equipment build or enemy rally healing.
const Spec = preload("res://scripts/catalog/exploration_enemy_catalog.gd")
const SentryVisual = preload("res://scripts/visuals/sentry_visual.gd")
const Navigation = preload("res://scripts/ai/cpu_navigation.gd")
var spec: Dictionary = Spec.SENTRY
var attack_phase := "grace"
var attack_time := 1.0
var melee_damage_window := 0.0
var attack_angle := 0.0
var route: Array = []
var route_time := 0.0
var gait_phase := 0.0
var motion_weight := 0.0
var visual_time := 0.0
var previous_visual_position := Vector2.ZERO
# Smoothed direction of actual movement (display only). While walking, the snapshot faces this way instead
# of toward the target, because the route bends around walls; combat aim is unaffected.
var visual_heading := Vector2.ZERO
# Off for actors whose drawing must keep pointing at the target while moving (the boss).
var face_movement := true
# Facing drawn while walking: follows visual_heading but only turns once the heading is more than
# FACING_TURN away, so a route running near a diagonal does not flicker between front and side frames.
var visual_facing := Vector2.ZERO
const FACING_TURN := deg_to_rad(55.0)

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
	visual_heading = Vector2.ZERO
	visual_facing = Vector2.ZERO
	reset(spawn)

func recover_rally(_dealt: float) -> void:
	pass

func reset(spawn: Vector2) -> void:
	melee_damage_window = 0.0
	super.reset(spawn)

func separate_melee_window(origin: Dictionary) -> bool:
	return spec.id != "furnace_warden" and origin.get("kind","") == "melee"

func damage_window_blocks(volley: int, origin: Dictionary) -> bool:
	if separate_melee_window(origin):
		# Only bypass a known projectile hit, never unrelated invulnerability.
		return melee_damage_window > 0 or (state.inv > 0 and (state.last_volley < 0 or state.inv > .22))
	return super.damage_window_blocks(volley,origin)

func record_damage_window(volley: int, origin: Dictionary) -> void:
	if separate_melee_window(origin):
		melee_damage_window = .22
	else:
		super.record_damage_window(volley,origin)

func hurt(amount: float, volley: int = -1, hazard: bool = false, origin: Dictionary = {}, attacker = null) -> bool:
	var alive: bool = state.hp > 0
	var applied := super.hurt(amount,volley,hazard,origin,attacker)
	if applied and alive and state.hp <= 0:
		if spec.get("machine_audio",false): sound_requested.emit("machine_stop",get_instance_id())
		sound_requested.emit(spec.death_sound,0)
		if spec.id != "furnace_warden": sound_requested.emit("enemy_defeat",0)
		var remains := preload("res://scripts/visuals/enemy_death.gd").new()
		remains.snapshot = enemy_visual_snapshot()
		remains.material = material
		for connection in sound_requested.get_connections():
			remains.sound_requested.connect(connection.callable)
		remains.organic = spec.id not in ["workshop_sentry","furnace_warden","scatter_drone","runner_sentry","ram_sentry","ring_sentry","ash_ram","triple_ring"]
		remains.position = state.pos
		remains.add_to_group("enemy_death_visuals")
		get_parent().add_child(remains)
	return applied

func advance_visual(dt: float, _moving: bool) -> void:
	var distance: float = state.pos.distance_to(previous_visual_position)
	var travel: Vector2 = state.pos-previous_visual_position
	previous_visual_position = state.pos
	visual_time += dt
	# Actual displacement drives feet; pushing against a wall does not walk in place.
	var walking: bool = distance > .01 and distance < 50 and (attack_phase == "chase" or (spec.get("walking_fire",false) and attack_phase == "spit") or (spec.id == "ash_ram" and attack_phase == "dash"))
	if walking:
		gait_phase += distance / 38.0 * TAU
		# Starting from a stop, take the new direction at once; while walking, smooth small route bends.
		var resumed := motion_weight < .1 or visual_heading == Vector2.ZERO
		visual_heading = travel.normalized() if resumed else visual_heading.lerp(travel.normalized(),clampf(dt*12.0,0,1))
		if resumed or absf(visual_facing.angle_to(visual_heading)) > FACING_TURN: visual_facing = visual_heading
	motion_weight = move_toward(motion_weight,1.0 if walking else 0.0,dt*10)

func sync_visual() -> void:
	position = state.pos
	for child in [$Sprite,$Animation,$Aim,$Identity,$Weapon,$Slash]: child.hide()
	queue_redraw()

func step(dt: float, i: int, enemy, arena, _mouse_shooting: bool = false, _ai: Dictionary = {}) -> bool:
	var command := preload("res://scripts/combat/combat_command.gd").idle(state.angle)
	if state.hp <= 0 or enemy == null or enemy.state.hp <= 0: return false
	var previous_time := attack_time
	attack_time = maxf(0.0,attack_time-dt)
	var delta: Vector2 = enemy.state.pos-state.pos
	if attack_phase == "windup":
		command.angle = attack_angle
		var lunge_time: float = spec.get("lunge_time",0.0)
		var lunge_dt := maxf(0.0,minf(previous_time,lunge_time)-minf(attack_time,lunge_time))
		if lunge_dt > 0:
			var direction := Vector2.from_angle(attack_angle)
			# Stop at body contact; commit to the telegraphed direction, never turn mid-lunge.
			var travel := minf(float(spec.get("lunge_speed",0.0))*lunge_dt,maxf(0.0,delta.dot(direction)-radius-enemy.radius))
			arena.move_fighter(state,direction*travel,radius)
			delta = enemy.state.pos-state.pos
		if attack_time <= 0:
			sound_requested.emit("sentry_swing",0)
			weapon_event_requested.emit({"kind":"enemy_attack","family":"sentry","pos":state.pos,"angle":attack_angle,"reach":spec.range})
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
			sound_requested.emit(spec.get("windup_sound","sentry_windup"),get_instance_id())
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
	melee_damage_window = maxf(0.0,melee_damage_window-dt)
	super.step(dt,i,enemy,arena,false,command)
	return false

# Values only: rendering cannot advance attacks or modify the combat state.
func enemy_visual_snapshot() -> Dictionary:
	var view := {"enemy_id":spec.id,"alive":not state.is_empty() and state.hp > 0,
		"phase":attack_phase,"remaining":attack_time,"windup":float(spec.windup),
		"gait":gait_phase,"motion":motion_weight,"visual_time":visual_time,
		"hit":clampf(maxf(float(state.get("inv",0)),melee_damage_window)/.22,0,1),
		"recovery":float(spec.recovery),"reach":float(spec.range),
		"angle":attack_angle if attack_phase in ["windup","recover"] else float(state.get("angle",0)),
		"hp_ratio":float(state.get("hp",0))/maxf(1.0,float(state.get("max_hp",1)))}
	if face_movement and attack_phase == "chase" and motion_weight > .1 and visual_facing.length() > .1:
		view.angle = visual_facing.angle()
	return view

func _draw() -> void:
	SentryVisual.paint(self,enemy_visual_snapshot())
