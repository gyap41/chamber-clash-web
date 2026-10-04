extends "res://scripts/combat/fire_pouch_lizard.gd"

func _init() -> void:
	spec = Spec.SCATTER
	face_movement = false

func resolved_definition(id: int) -> Dictionary:
	if id == Spec.SCATTER_ID: return Spec.SCATTER_BULLET.duplicate()
	return super.resolved_definition(id)

func spit(i: int, arena) -> void:
	if combat_service == null or combat_service.get_ref() == null:
		recover()
		return
	var session = combat_service.get_ref()
	var fired := false
	# Keep the original aim for both waves; the second wave shifts by half a gap.
	var shift := 0.0 if shots_left == 2 else .14
	for offset in [-.56,-.28,0.0,.28,.56]:
		var angle: float = attack_angle+offset+shift
		var origin: Vector2 = state.pos+Vector2.from_angle(angle)*24
		if preload("res://scripts/combat/projectile_collision.gd").solid(arena,origin,4) or preload("res://scripts/combat/projectile_collision.gd").line_blocked(arena,state.pos,origin): continue
		session.spawn_shot(i,Spec.SCATTER_ID,angle,{"pos":origin,"kind":"enemy_scatter",
			"speed":spec.projectile_speed,"damage":spec.damage,"radius":4.0,"life":spec.projectile_life,
			"color":"#ffcf70","visual_color":"#ffcf70","visual_weapon":0,"visual_variant":"enemy_scatter","can_lens":false})
		fired = true
	shots_left -= 1
	if fired: sound_requested.emit("sentry_swing",0)
	attack_phase = "spit"
	attack_time = spec.shot_interval

func _draw() -> void:
	preload("res://scripts/visuals/scatter_drone_visual.gd").paint(self,enemy_visual_snapshot())
