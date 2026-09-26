extends "res://scripts/combat/exploration_enemy.gd"
const LizardVisual = preload("res://scripts/visuals/lizard_visual.gd")
const Follow = preload("res://scripts/visuals/exploration_camera.gd")
var shots_left := 0

func _init() -> void:
	spec = Spec.LIZARD

func prepare(spawn: Vector2) -> void:
	attack_phase = "grace"
	shots_left = 0
	super.prepare(spawn)

func resolved_definition(id: int) -> Dictionary:
	if id == Spec.FIRE_SEED_ID: return Spec.FIRE_SEED.duplicate()
	return super.resolved_definition(id)

func visible_to_target(arena, target: Vector2) -> bool:
	# The logical play rectangle excludes HUD; do not depend on render-frame timing.
	return Follow.visible_rect(arena.field_rect,target).grow(-28/Follow.zoom()).has_point(state.pos)

func recover() -> void:
	shots_left = 0
	attack_phase = "recover"
	attack_time = spec.recovery

func spit(i: int, arena) -> void:
	var direction := Vector2.from_angle(attack_angle)
	var mouth: Vector2 = state.pos+direction*22
	# A protruding sprite must not allow a projectile to start beyond a nearby wall.
	if arena.solid(mouth,6) or arena.line_blocked(state.pos,mouth):
		recover()
		return
	if combat_service == null or combat_service.get_ref() == null:
		recover()
		return
	var session = combat_service.get_ref()
	session.spawn_shot(i,Spec.FIRE_SEED_ID,attack_angle,{"pos":mouth,"kind":"enemy_fire_seed",
		"speed":spec.projectile_speed,"damage":spec.damage,"radius":6.0,"life":spec.projectile_life,
		"color":"#ff9a43","visual_color":"#ff9a43","visual_weapon":2,"visual_variant":"enemy_fire_seed",
		"can_lens":false})
	shots_left -= 1
	sound_requested.emit("lizard_spit",0)
	attack_phase = "spit"
	attack_time = spec.shot_interval

func step(dt: float, i: int, enemy, arena, _mouse_shooting: bool = false, _ai: Dictionary = {}) -> bool:
	if state.hp <= 0 or enemy == null or enemy.state.hp <= 0: return false
	var command := preload("res://scripts/combat/combat_command.gd").idle(state.angle)
	var delta: Vector2 = enemy.state.pos-state.pos
	var seen := visible_to_target(arena,enemy.state.pos)
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
		if seen and delta.length() <= spec.range and not arena.line_blocked(state.pos,enemy.state.pos):
			attack_phase = "windup"
			attack_time = spec.windup
			attack_angle = delta.angle()
			shots_left = spec.get("shots",2)
			sound_requested.emit(spec.get("windup_sound","lizard_inhale"),0)
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
	return move_with_command(dt,i,enemy,arena,command)

func enemy_visual_snapshot() -> Dictionary:
	var view := super.enemy_visual_snapshot()
	if attack_phase == "spit": view.angle = attack_angle
	view.shots_left = shots_left
	return view

func _draw() -> void:
	LizardVisual.paint(self,enemy_visual_snapshot())
