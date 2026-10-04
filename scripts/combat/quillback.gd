extends "res://scripts/combat/fire_pouch_lizard.gd"

func _init() -> void:
	spec = Spec.QUILLBACK

func resolved_definition(id: int) -> Dictionary:
	if id == Spec.QUILL_ID: return Spec.QUILL.duplicate()
	return super.resolved_definition(id)

func spit(i: int, arena) -> void:
	if combat_service == null or combat_service.get_ref() == null:
		recover()
		return
	var session = combat_service.get_ref()
	var fired := false
	var offsets := [-.44,-.22,0.0,.22,.44] if shots_left != 1 else [-.33,-.11,.11,.33]
	for offset in offsets:
		var angle: float = attack_angle+offset
		var origin: Vector2 = state.pos+Vector2.from_angle(angle)*24
		if preload("res://scripts/combat/projectile_collision.gd").solid(arena,origin,4) or preload("res://scripts/combat/projectile_collision.gd").line_blocked(arena,state.pos,origin): continue
		session.spawn_shot(i,Spec.QUILL_ID,angle,{"pos":origin,"kind":"enemy_quill",
			"speed":spec.projectile_speed,"damage":spec.damage,"radius":4.0,"life":spec.projectile_life,
			"color":"#ffe4ac","visual_color":"#ffe4ac","visual_weapon":0,"visual_variant":"enemy_quill","can_lens":false})
		fired = true
	shots_left = maxi(0,shots_left-1)
	if fired:
		sound_requested.emit("quill_fire",0)
		weapon_event_requested.emit({"kind":"enemy_attack","family":"quill","pos":state.pos,"angle":attack_angle,"offsets":offsets})
	attack_phase = "spit"
	attack_time = spec.shot_interval
