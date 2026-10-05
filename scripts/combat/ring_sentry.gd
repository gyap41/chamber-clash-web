extends "res://scripts/combat/scatter_drone.gd"
var firing_muzzles: Array[int] = []
func _init() -> void:
	spec = Spec.RING
	face_movement = false
func spit(i: int, arena) -> void:
	firing_muzzles.clear()
	if combat_service == null or combat_service.get_ref() == null:
		recover()
		return
	var session = combat_service.get_ref()
	var fired := false
	# A persistent 90-degree escape sector faces the locked target direction.
	# Both waves preserve that same opening; never close it by tracking the player.
	for n in range(3,14):
		var angle: float = attack_angle+n*TAU/16
		var origin: Vector2 = state.pos+Vector2.from_angle(angle)*26
		if preload("res://scripts/combat/projectile_collision.gd").solid(arena,origin,4) or preload("res://scripts/combat/projectile_collision.gd").line_blocked(arena,state.pos,origin): continue
		session.spawn_shot(i,Spec.SCATTER_ID,angle,{"pos":origin,"kind":"enemy_ring",
			"speed":spec.projectile_speed,"damage":spec.damage,"radius":4.0,"life":spec.projectile_life,
			"color":"#ffcf70","visual_color":"#ffcf70","visual_weapon":0,"visual_variant":"enemy_scatter","can_lens":false})
		firing_muzzles.append(n)
		fired = true
	shots_left -= 1
	if fired: sound_requested.emit(spec.get("attack_sound","sentry_swing"),get_instance_id() if spec.get("machine_audio",false) else 0)
	attack_phase = "spit"
	attack_time = spec.shot_interval
func _draw() -> void:
	if preload("res://scripts/visuals/remaining_machine_visual.gd").paint(self,enemy_visual_snapshot()): return
	preload("res://scripts/visuals/sentry_variants_visual.gd").paint(self,enemy_visual_snapshot())
