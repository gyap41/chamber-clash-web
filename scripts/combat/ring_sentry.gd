extends "res://scripts/combat/scatter_drone.gd"
func _init() -> void:
	spec = Spec.RING
	face_movement = false
func spit(i: int, arena) -> void:
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
		if arena.solid(origin,4) or arena.line_blocked(state.pos,origin): continue
		session.spawn_shot(i,Spec.SCATTER_ID,angle,{"pos":origin,"kind":"enemy_ring",
			"speed":spec.projectile_speed,"damage":spec.damage,"radius":4.0,"life":spec.projectile_life,
			"color":"#ffcf70","visual_color":"#ffcf70","visual_weapon":0,"visual_variant":"enemy_scatter","can_lens":false})
		fired = true
	shots_left -= 1
	if fired: sound_requested.emit("sentry_swing",0)
	attack_phase = "spit"
	attack_time = spec.shot_interval
func _draw() -> void:
	preload("res://scripts/visuals/sentry_variants_visual.gd").paint(self,enemy_visual_snapshot())
