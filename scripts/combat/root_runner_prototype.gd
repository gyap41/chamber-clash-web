extends "res://scripts/combat/runner_sentry.gd"
# Moss beetle used in authored production encounters and previews.
const Rig = preload("res://scripts/visuals/root_runner_rig.gd")
var rig
const DASH_DISTANCE := 420.0
const DASH_SPEED := 560.0
var dash_travel := 0.0
var dash_hit := false
var stop_reason := ""
var dash_elapsed := 0.0
var bounce_count := 0
var bounce_flash := 0.0
func _init() -> void:
	spec = Spec.RUNNER.duplicate(true)
	spec.speed = 72.0
	spec.range = 328.0
	spec.windup = .5
	spec.recovery = .9
	spec.id = "root_runner_prototype"
	spec.windup_sound = "moss_curl"
	spec.death_sound = "moss_down"
	spec.name = "苔玉コガネ"
func prepare(spawn: Vector2) -> void:
	dash_elapsed=0
	bounce_count=0
	bounce_flash=0
	dash_travel = 0
	dash_hit = false
	stop_reason = ""
	super.prepare(spawn)
	if rig == null:
		rig = Rig.new()
		add_child(rig)
	rig.reset_pose()
	rig.show()
func recover_tackle(reason: String) -> void:
	sound_requested.emit("moss_stop",get_instance_id())
	attack_phase = "recover"
	attack_time = spec.recovery
	stop_reason = reason
func step(dt: float, i: int, enemy, arena, shooting: bool = false, ai: Dictionary = {}) -> bool:
	if state.hp <= 0 or enemy == null or enemy.state.hp <= 0:
		sound_requested.emit("moss_stop",get_instance_id())
		return false
	bounce_flash=maxf(0,bounce_flash-dt)
	if attack_phase == "recover":
		var before := float(spec.recovery)-attack_time
		attack_time=maxf(0,attack_time-dt)
		var after := float(spec.recovery)-attack_time
		if stop_reason == "contact":
			# Rebound while tucked away. Obstacles stop the rebound without sliding sideways.
			var remaining := 40.0*(ease_out(after/.18)-ease_out(before/.18))
			while remaining > .0001:
				var stride := minf(remaining,3.0)
				var next: Vector2 = state.pos-Vector2.from_angle(attack_angle)*stride
				if not arena.fighter_bounds.grow(-radius).has_point(next) or arena.solid(next,radius): break
				state.pos=next
				remaining-=stride
		if attack_time <= 0: attack_phase="chase"
		return move_with_command(dt,i,enemy,arena,preload("res://scripts/combat/combat_command.gd").idle(attack_angle))
	if attack_phase == "windup":
		attack_time = maxf(0,attack_time-dt)
		if attack_time <= 0:
			attack_phase = "dash"
			sound_requested.emit("moss_dash",get_instance_id())
		return move_with_command(dt,i,enemy,arena,preload("res://scripts/combat/combat_command.gd").idle(attack_angle))
	if attack_phase == "dash":
		sound_requested.emit("moss_roll_low" if dash_speed(dash_elapsed)<480 else "moss_roll",get_instance_id())
		var time_left := dt
		while time_left > .00001 and attack_phase == "dash":
			var tick := minf(time_left,1.0/240)
			var speed := (dash_speed(dash_elapsed)+dash_speed(dash_elapsed+tick))*.5
			var stride := minf(DASH_DISTANCE-dash_travel,speed*tick)
			dash_elapsed+=tick
			time_left-=tick
			var axis := Vector2.from_angle(attack_angle)
			var next: Vector2 = state.pos+axis*stride
			if blocked(arena,next):
				sound_requested.emit("moss_wall",get_instance_id())
				if bounce_count >= 1:
					recover_tackle("wall")
					break
				var normal := wall_normal(arena,next,axis)
				attack_angle=axis.bounce(normal).angle()
				bounce_count+=1
				bounce_flash=.12
				continue
			state.pos=next
			dash_travel+=stride
			if state.pos.distance_to(enemy.state.pos)<=radius+enemy.radius and not arena.line_blocked(state.pos,enemy.state.pos):
				if not dash_hit:
					enemy.hurt(spec.damage,-1,false,{"kind":"enemy_tackle","enemy":participant_id},self)
					dash_hit=true
					sound_requested.emit("moss_contact",get_instance_id())
				recover_tackle("contact")
			if dash_travel >= DASH_DISTANCE-.001: recover_tackle("miss")

		return move_with_command(dt,i,enemy,arena,preload("res://scripts/combat/combat_command.gd").idle(attack_angle))
	var was_phase := attack_phase
	var result := super.step(dt,i,enemy,arena,shooting,ai)
	if was_phase != "windup" and attack_phase == "windup":
		dash_elapsed=0
		bounce_count=0
		bounce_flash=0
		dash_travel = 0
		dash_hit = false
		stop_reason = ""
	return result
func dash_speed(elapsed: float) -> float:
	return lerpf(220.0,DASH_SPEED,clampf(elapsed/.08,0,1))*(.78 if bounce_count else 1.0)
func blocked(arena, point: Vector2) -> bool:
	return not arena.fighter_bounds.grow(-radius).has_point(point) or arena.solid(point,radius)
func wall_normal(arena, point: Vector2, axis: Vector2) -> Vector2:
	var bounds: Rect2 = arena.fighter_bounds.grow(-radius)
	var normal := Vector2.ZERO
	if point.x<bounds.position.x: normal.x=1
	elif point.x>=bounds.end.x: normal.x=-1
	if point.y<bounds.position.y: normal.y=1
	elif point.y>=bounds.end.y: normal.y=-1
	if normal.length_squared()>0: return normal.normalized()
	var rects: Array[Rect2] = []
	for wall in arena.get_node("Walls").get_children(): rects.append(wall.collision_rect())
	if arena.runtime_definition != null:
		for placement in arena.runtime_definition.placements:
			if placement.collision != Rect2(): rects.append(Rect2(placement.position+placement.collision.position,placement.collision.size))
	for rect in rects:
		var offset := point-point.clamp(rect.position,rect.end)
		if offset.length_squared()>0 and offset.length()<radius and axis.dot(offset)<0:
			return offset.normalized()
	# Irregular floor edges have no wall rectangle; sample the free-space gradient.
	normal=Vector2(float(blocked(arena,point-Vector2(2,0)))-float(blocked(arena,point+Vector2(2,0))),float(blocked(arena,point-Vector2(0,2)))-float(blocked(arena,point+Vector2(0,2))))
	return normal.normalized() if normal.length_squared()>0 else -axis
static func ease_out(value: float) -> float:
	var t := clampf(value,0,1)
	return 1.0-(1.0-t)*(1.0-t)
func enemy_visual_snapshot() -> Dictionary:
	var snapshot := super.enemy_visual_snapshot()
	snapshot.dash_progress = clampf(dash_travel/DASH_DISTANCE,0,1)
	snapshot.roll_turns=dash_travel/100.0
	snapshot.bounce_flash=bounce_flash
	snapshot.bounce_count=bounce_count
	if attack_phase == "dash": snapshot.angle = attack_angle
	if rig != null:
		snapshot.death_facing=rig.facing
		snapshot.death_facing_index=rig.facing_index
		snapshot.death_pose=Rig.attack_pose(rig.view)
		snapshot.death_feet=rig.feet.duplicate(true)
		snapshot.death_world=rig.world
		snapshot.death_body_offset=rig.body_offset
	return snapshot
func advance_visual(dt: float, moving: bool) -> void:
	var travel: Vector2 = state.pos-previous_visual_position
	if travel.length() >= 50: travel = Vector2.ZERO
	super.advance_visual(dt,moving)
	if rig != null: rig.advance(dt,travel,enemy_visual_snapshot())
func _draw() -> void:
	pass

func hurt(amount: float, volley: int = -1, hazard: bool = false, origin: Dictionary = {}, attacker = null) -> bool:
	var applied := super.hurt(amount,volley,hazard,origin,attacker)
	if state.hp<=0:
		sound_requested.emit("moss_stop",get_instance_id())
		if rig != null: rig.hide()
	return applied
