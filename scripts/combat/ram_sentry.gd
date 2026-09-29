extends "res://scripts/combat/fire_pouch_lizard.gd"
var dash_left := 0.0
var dash_hit := false
func _init() -> void:
	spec = Spec.RAM
	face_movement = false
func prepare(spawn: Vector2) -> void:
	dash_left = 0
	dash_hit = false
	super.prepare(spawn)
func spit(_i: int, _arena) -> void:
	attack_phase = "dash"
	dash_left = 310
	dash_hit = false
	shots_left = 0
	sound_requested.emit("sentry_swing",0)
func step(dt: float, i: int, enemy, arena, shooting: bool = false, ai: Dictionary = {}) -> bool:
	if state.hp <= 0 or enemy == null or enemy.state.hp <= 0: return false
	if attack_phase != "dash": return super.step(dt,i,enemy,arena,shooting,ai)
	var remaining := minf(dash_left,400*dt)
	while remaining > 0:
		var stride := minf(remaining,6)
		var next: Vector2 = state.pos+Vector2.from_angle(attack_angle)*stride
		if not arena.fighter_bounds.has_point(next) or arena.solid(next,radius):
			dash_left = 0
			break
		state.pos = next
		remaining -= stride
		dash_left -= stride
		if not dash_hit and state.pos.distance_to(enemy.state.pos) <= radius+enemy.radius and not arena.line_blocked(state.pos,enemy.state.pos):
			enemy.hurt(spec.damage,-1,false,{"kind":"enemy_charge","enemy":participant_id},self)
			dash_hit = true
			dash_left = 0
			break
	if dash_left <= 0: recover()
	return move_with_command(dt,i,enemy,arena,preload("res://scripts/combat/combat_command.gd").idle(attack_angle))
func enemy_visual_snapshot() -> Dictionary:
	var view := super.enemy_visual_snapshot()
	if attack_phase == "dash": view.angle = attack_angle
	return view
func _draw() -> void:
	preload("res://scripts/visuals/sentry_variants_visual.gd").paint(self,enemy_visual_snapshot())
