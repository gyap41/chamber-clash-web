extends "res://scripts/combat/exploration_enemy.gd"
const LizardVisual = preload("res://scripts/visuals/lizard_visual.gd")
const Follow = preload("res://scripts/visuals/exploration_camera.gd")
var shots_left := 0
var previous_target := Vector2.ZERO
var target_known := false
var target_velocity := Vector2.ZERO

func _init() -> void:
	spec = Spec.LIZARD

func prepare(spawn: Vector2) -> void:
	if spec.get("machine_audio",false): sound_requested.emit("machine_stop",get_instance_id())
	attack_phase = "grace"
	shots_left = 0
	target_known = false
	target_velocity = Vector2.ZERO
	super.prepare(spawn)

func resolved_definition(id: int) -> Dictionary:
	if id == Spec.FIRE_SEED_ID: return Spec.FIRE_SEED.duplicate()
	return super.resolved_definition(id)

func visible_to_target(arena, target: Vector2) -> bool:
	# The logical play rectangle excludes HUD; do not depend on render-frame timing.
	return Follow.visible_rect(arena.field_rect,target).grow(-28/Follow.zoom()).has_point(state.pos)

func recover() -> void:
	if spec.get("machine_audio",false):
		sound_requested.emit("machine_stop",get_instance_id())
		if attack_phase in ["dash","spit"] and state.hp > 0: sound_requested.emit("machine_vent",get_instance_id())
	shots_left = 0
	attack_phase = "recover"
	attack_time = spec.recovery

func shot_angle() -> float:
	var offsets: Array = spec.get("spray",[0.0])
	var index := maxi(0,int(spec.get("shots",2))-shots_left)
	return attack_angle+float(offsets[index%offsets.size()])

func spit(i: int, arena) -> void:
	var emitted_angle := shot_angle()
	var direction := Vector2.from_angle(emitted_angle)
	var mouth: Vector2 = state.pos+direction*22
	# A protruding sprite must not allow a projectile to start beyond a nearby wall.
	if preload("res://scripts/combat/projectile_collision.gd").solid(arena,mouth,Spec.FIRE_SEED_RADIUS) or preload("res://scripts/combat/projectile_collision.gd").line_blocked(arena,state.pos,mouth):
		recover()
		return
	if combat_service == null or combat_service.get_ref() == null:
		recover()
		return
	var session = combat_service.get_ref()
	session.spawn_shot(i,Spec.FIRE_SEED_ID,emitted_angle,{"pos":mouth,"kind":"enemy_fire_seed",
		"speed":spec.projectile_speed,"damage":spec.damage,"radius":Spec.FIRE_SEED_RADIUS,"life":spec.projectile_life,
		"color":"#ff9a43","visual_color":"#ff9a43","visual_weapon":2,"visual_variant":"enemy_fire_seed",
		"can_lens":false})
	shots_left -= 1
	weapon_event_requested.emit({"kind":"enemy_attack","family":"flame","pos":mouth,"angle":emitted_angle})
	sound_requested.emit("lizard_spit",0)
	attack_phase = "spit"
	attack_time = spec.shot_interval

func step(dt: float, i: int, enemy, arena, _mouse_shooting: bool = false, _ai: Dictionary = {}) -> bool:
	if state.hp <= 0 or enemy == null or enemy.state.hp <= 0: return false
	var command := preload("res://scripts/combat/combat_command.gd").idle(state.angle)
	var mobile: bool = spec.get("walking_fire",false)
	if mobile and dt > 0:
		target_velocity = ((enemy.state.pos-previous_target)/dt).limit_length(230) if target_known else Vector2.ZERO
		previous_target = enemy.state.pos
		target_known = true
	var delta: Vector2 = enemy.state.pos-state.pos
	var lead: Vector2 = (target_velocity*float(spec.get("lead_time",0))).limit_length(70)
	var seen := visible_to_target(arena,enemy.state.pos)
	# Only configured enemies re-aim. Freeze the final tell before each shot.
	if spec.has("aim_lock") and attack_phase in ["windup","spit"] and shots_left > 0 and attack_time > float(spec.aim_lock):
		attack_angle = (delta+lead).angle()
	attack_time = maxf(0,attack_time-dt)
	if attack_phase in ["windup","spit"]:
		command.angle = attack_angle
		if not seen:
			recover()
		elif attack_time <= 0:
			if shots_left > 0: spit(i,arena)
			else: recover()
	elif attack_time <= 0:
		attack_phase = "chase"
		command.angle = delta.angle()
		if seen and delta.length() <= spec.range and not preload("res://scripts/combat/projectile_collision.gd").line_blocked(arena,state.pos,enemy.state.pos):
			attack_phase = "windup"
			attack_time = spec.windup
			attack_angle = (delta+lead).angle()
			shots_left = spec.get("shots",2)
			sound_requested.emit(spec.get("windup_sound","lizard_inhale"),get_instance_id() if spec.get("machine_audio",false) else 0)
		elif Navigation.segment_clear(arena,state.pos,enemy.state.pos):
			var axis := delta.normalized()
			command.dx = axis.x
			command.dy = axis.y
			route.clear()
		else:
			route_time -= dt
			if route_time <= 0:
				route = Navigation.combat_path(arena,state.pos,enemy.state.pos,Vector2(0,spec.range-20),16384)
				route_time = .65
			while not route.is_empty() and state.pos.distance_to(route[0]) < 6: route.pop_front()
			if not route.is_empty():
				var axis: Vector2 = (route[0]-state.pos).normalized()
				command.dx = axis.x
				command.dy = axis.y
	# Only the two fire lizards move during their volley. Other ranged subclasses remain planted.
	var firing_walk: bool = mobile and seen and attack_phase == "spit" and shots_left > 0
	if firing_walk:
		var forward := delta.normalized()
		var axis: Vector2 = forward*(1.0 if delta.length() > 200 else (-.5 if delta.length() < 135 else 0.0))
		axis += forward.orthogonal()*.45*(1.0 if int(spec.get("shots",5))%2 == 1 else -1.0)
		command.dx = axis.x
		command.dy = axis.y
	var original_speed := move_speed
	if firing_walk: move_speed *= float(spec.fire_move_ratio)
	var result := move_with_command(dt,i,enemy,arena,command)
	move_speed = original_speed
	return result

func enemy_visual_snapshot() -> Dictionary:
	var view := super.enemy_visual_snapshot()
	if attack_phase == "spit": view.angle = attack_angle
	view.shots_left = shots_left
	view.walking_fire = spec.get("walking_fire",false)
	view.shot_interval = float(spec.get("shot_interval",.3))
	return view

func _draw() -> void:
	LizardVisual.paint(self,enemy_visual_snapshot())
