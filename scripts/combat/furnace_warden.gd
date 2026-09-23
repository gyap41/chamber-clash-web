extends "res://scripts/combat/fire_pouch_lizard.gd"
const BOLT_ID := -3
var startup_total := 0.0
var move_index := 0
var last_attack := ""
const NORMAL_MOVES := ["dash","machinegun","salvo","shockwave","cannon"]
const ENRAGED_MOVES := ["shockwave","machinegun","dash","salvo","cannon","machinegun"]
var move_name := "salvo"
var second_phase := false
var waves: Array = []
var emission_time := 0.0
var emissions_left := 0
var dash_left := 0.0
var chain_left := 0
var combo_finisher := false
var wave_cooldown := 0.0
var spin_time := 0.0
var opening := 0.0
var lift := 0.0
var impact_age := 10.0
var impact_kind := ""
var flash_age := 10.0
var particles: Array = []
var particle_clock := 0.0
var particle_serial := 0
var dash_age := 0.0
var drive := 0.0
var recoil := 0.0
var muzzle_angle := 0.0
var muzzle_angles: Array = []
var salvo_index := 0
const MUZZLE_DISTANCE := 52.0
const WAVE_SPEED := 420.0
const WAVE_INTERVAL := 2.1
const JUMP_TIME := .65

func _init() -> void:
	spec = {"id":"furnace_warden","name":"独楽の鋳造機","death_sound":"boss_internal",
		"hp":48.0,"speed":76.0,"radius":44.0,"range":410.0,"damage":1.5,"windup":1.0,"recovery":1.5,"entry_grace":1.5}

func prepare(spawn: Vector2) -> void:
	startup_total = 0.0
	waves.clear()
	particles.clear()
	wave_cooldown = 0
	spin_time = 0
	dash_age = 0
	drive = 0
	recoil = 0
	opening = 0
	lift = 0
	impact_age = 10
	flash_age = 10
	muzzle_angles.clear()
	salvo_index = 0
	particle_clock = 0
	emissions_left = 0
	dash_left = 0
	chain_left = 0
	combo_finisher = false
	move_index = 0
	last_attack = ""
	second_phase = false
	move_name = "salvo"
	super.prepare(spawn)

func resolved_definition(id: int) -> Dictionary:
	if id == BOLT_ID: return {"speed":230.0,"damage":1.0,"color":"#ffbd70"}
	return super.resolved_definition(id)

func hurt(amount: float, volley: int = -1, hazard: bool = false, origin: Dictionary = {}, attacker = null) -> bool:
	if attack_phase in ["grace","transition"]: return false
	return super.hurt(amount,volley,hazard,origin,attacker)

func step(dt: float, i: int, enemy, arena, _shooting: bool = false, _ai: Dictionary = {}) -> bool:
	if state.hp <= 0 or enemy == null or enemy.state.hp <= 0: return false
	wave_cooldown = maxf(0,wave_cooldown-dt)
	step_waves(dt,enemy,arena)
	var command := preload("res://scripts/combat/combat_command.gd").idle(state.angle)
	var delta: Vector2 = enemy.state.pos-state.pos
	var seen := visible_to_target(arena,enemy.state.pos)
	var continuing := attack_visible(arena,enemy.state.pos)
	attack_time = maxf(0,attack_time-dt)
	if not second_phase and state.hp <= state.max_hp*.5:
		second_phase = true
		attack_phase = "transition"
		attack_time = 1.2
		move_index = 0
		emissions_left = 0
		waves.clear()
		combo_finisher = false
		wave_cooldown = 0
		chain_left = 0
		sound_requested.emit("boss_overdrive",0)
	if attack_phase == "dash":
		dash_age += dt
		var acceleration := lerpf(.65,1.0,clampf(dash_age/.1,0,1))
		var braking := lerpf(.65,1.0,clampf(dash_left/90.0,0,1))
		var amount := minf(dash_left,(800.0 if second_phase else 650.0)*acceleration*braking*dt)
		var before: Vector2 = state.pos
		# Short segments prevent tunnelling through the boundary at large frame times.
		var remaining := amount
		while remaining > 0:
			var stride := minf(remaining,8.0)
			var next: Vector2 = state.pos+Vector2.from_angle(attack_angle)*stride
			if arena.solid(next,radius) or not arena.fighter_bounds.has_point(next):
				dash_left = 0
				break
			state.pos = next
			remaining -= stride
		var travelled: float = before.distance_to(state.pos)
		dash_left = maxf(0,dash_left-travelled)
		# Vector2 coordinates have less precision than the remaining scalar distance.
		# Finish within half a pixel, or when a positive step cannot move the body.
		if dash_left <= .5 or (amount > 0 and travelled <= .001) or state.pos.distance_to(enemy.state.pos) <= 110:
			if state.pos.distance_to(enemy.state.pos) > 180 or arena.line_blocked(state.pos,enemy.state.pos):
				cancel_to_chase()
				step_presentation(dt)
				return move_with_command(dt,i,enemy,arena,command)
			move_name = "slam"
			# A short final lift leaves a reaction window after closing the gap.
			attack_phase = "windup"
			attack_time = .3
	elif attack_phase == "machinegun":
		if not continuing:
			cancel_to_chase()
			var axis := chase_direction(dt,enemy.state.pos,arena)
			command.dx = axis.x
			command.dy = axis.y
		else:
			var tracking := 1.3 if second_phase else .85
			attack_angle = rotate_toward(attack_angle,delta.angle(),tracking*dt)
			command.angle = attack_angle
			emission_time -= dt
			if emission_time <= 0 and emissions_left > 0:
				if emissions_left%6 == 0:
					for offset in [-.6,-.3,.3,.6]:
						fire_bolt(i,arena,attack_angle+offset,290.0 if second_phase else 250.0,false)
				fire_bolt(i,arena,attack_angle+sin(emissions_left*1.7)*.055,480.0 if second_phase else 420.0)
				emissions_left -= 1
				emission_time = .055 if second_phase else .08
			if emissions_left == 0: begin_recovery()
	elif attack_phase in ["salvo","cannon"]:
		command.angle = attack_angle
		if not continuing:
			cancel_to_chase()
			var axis := chase_direction(dt,enemy.state.pos,arena)
			command.dx = axis.x
			command.dy = axis.y
		else:
			# Re-aim between heavy shots, then leave a committed dodge window.
			if attack_phase == "cannon" and emission_time > .25:
				attack_angle = rotate_toward(attack_angle,delta.angle(),dt*2.6)
			emission_time -= dt
			if emission_time <= 0 and emissions_left > 0:
				if attack_phase == "salvo": fire_salvo(i,arena)
				else: fire_cannon(i,arena,attack_angle,true)
				emissions_left -= 1
				emission_time = (.36 if second_phase else .48) if attack_phase == "salvo" else .85
			if emissions_left == 0: begin_recovery()
	elif attack_phase == "shockwave":
		emission_time -= dt
		if emission_time <= 0 and emissions_left > 0:
			waves.append({"origin":state.pos,"radius":0.0,"resolved":false,"previous":enemy.state.pos})
			wave_cooldown = WAVE_INTERVAL
			emissions_left -= 1
			emission_time = WAVE_INTERVAL
			lift = 0
			impact_age = 0
			impact_kind = "wave"
			sound_requested.emit("boss_impact",0)
		if emissions_left == 0 and emission_time <= WAVE_INTERVAL-.4: begin_recovery()
	elif attack_phase == "windup":
		if move_name == "cannon" and attack_time > .25:
			attack_angle = rotate_toward(attack_angle,delta.angle(),dt*2.6)
		command.angle = attack_angle
		if not continuing:
			cancel_to_chase()
			var axis := chase_direction(dt,enemy.state.pos,arena)
			command.dx = axis.x
			command.dy = axis.y
		elif attack_time <= 0:
			if move_name == "dash":
				attack_phase = "dash"
				dash_age = 0
				sound_requested.emit("boss_dash",0)
				dash_left = clampf(delta.length()-100,0,620)
			elif move_name in ["machinegun","salvo","cannon","shockwave"]:
				attack_phase = move_name
				match move_name:
					"machinegun": emissions_left = 42 if second_phase else 24
					"shockwave": emissions_left = 4 if second_phase else 3
					"salvo": emissions_left = 3 if second_phase else 2
					"cannon": emissions_left = 2 if second_phase else 1
				salvo_index = 0
				emission_time = JUMP_TIME if move_name == "shockwave" else 0
			elif move_name == "slam" and combo_finisher and chain_left == 0:
				# Replace the final melee hit with a readable jump and one full ring.
				combo_finisher = false
				move_name = "shockwave"
				attack_phase = "shockwave"
				emissions_left = 1
				emission_time = maxf(1.0,wave_cooldown)
			else:
				execute_attack(i,enemy,arena)
				if move_name == "slam" and chain_left > 0:
					chain_left -= 1
					move_name = "dash"
					attack_angle = delta.angle()
					attack_time = .65
				else:
					begin_recovery()
	elif attack_time <= 0:
		attack_phase = "chase"
		command.angle = delta.angle()
		var choice := choose_attack(enemy.state.pos,arena) if seen and not arena.line_blocked(state.pos,enemy.state.pos) else {}
		if not choice.is_empty():
			move_name = choice.move
			last_attack = choice.family
			move_index = choice.next_index
			attack_phase = "windup"
			attack_angle = delta.angle()
			attack_time = (.7 if second_phase else 1.0) if move_name != "shockwave" else 1.3
			chain_left = (2 if second_phase else 1) if move_name in ["dash","slam"] else 0
			combo_finisher = second_phase and move_name in ["dash","slam"]
			sound_requested.emit("sentry_windup",0)
		else:
			var axis := chase_direction(dt,enemy.state.pos,arena)
			command.dx = axis.x
			command.dy = axis.y
	step_presentation(dt)
	return move_with_command(dt,i,enemy,arena,command)

# Rotate through roles, skipping unusable moves instead of waiting on a melee slot.
# Only commit the cursor when an attack actually starts. No presentation RNG.
func choose_attack(target: Vector2, arena) -> Dictionary:
	var distance: float = state.pos.distance_to(target)
	if distance > 700: return {}
	var sequence: Array = ENRAGED_MOVES if second_phase else NORMAL_MOVES
	for offset in range(sequence.size()):
		var cursor := (move_index+offset)%sequence.size()
		var family: String = sequence[cursor]
		if family == last_attack: continue
		var chosen := family
		if family == "dash":
			if distance <= 165:
				chosen = "slam"
			elif distance < 200 or not preload("res://scripts/ai/cpu_navigation.gd").segment_clear(arena,state.pos,target,radius):
				continue
		return {"move":chosen,"family":family,"next_index":(cursor+1)%sequence.size()}
	return {}

# Start conservatively, but do not cancel a committed attack just because its
# ground origin crossed the inset viewport edge while the body is still visible.
func attack_visible(arena, target: Vector2) -> bool:
	var origin := Follow.origin(arena.field_rect,target)+Follow.PLAY_OFFSET
	return Rect2(origin,Follow.PLAY_SIZE).intersects(Rect2(state.pos+Vector2(-85,-155),Vector2(170,180)))

func cancel_to_chase() -> void:
	combo_finisher = false
	emissions_left = 0
	chain_left = 0
	attack_phase = "chase"
	attack_time = 0
	route_time = 0

func begin_recovery() -> void:
	combo_finisher = false
	sound_requested.emit("boss_vent",0)
	emissions_left = 0
	chain_left = 0
	attack_phase = "recover"
	attack_time = .55 if second_phase else 1.1

func fire_bolt(i: int, arena, angle: float, speed: float, cue: bool = true) -> void:
	if combat_service == null or combat_service.get_ref() == null: return
	var origin: Vector2 = state.pos+Vector2.from_angle(angle)*MUZZLE_DISTANCE
	if arena.solid(origin,6) or arena.line_blocked(state.pos,origin): return
	combat_service.get_ref().spawn_shot(i,BOLT_ID,angle,{"pos":origin,"speed":speed,"damage":.85,
		"radius":6.0,"life":3.6,"visual_weapon":2,"visual_variant":"boss_rivet","can_lens":false})
	if cue:
		flash_age = 0
		recoil = .6
		muzzle_angle = angle
		muzzle_angles = [angle]
		sound_requested.emit("rapid",0)

func fire_cannon(i: int, arena, angle: float, heavy: bool, cue: bool = true) -> bool:
	if combat_service == null or combat_service.get_ref() == null: return false
	var shot_radius := 14.0 if heavy else 7.0
	var origin: Vector2 = state.pos+Vector2.from_angle(angle)*MUZZLE_DISTANCE
	if arena.solid(origin,shot_radius) or arena.line_blocked(state.pos,origin): return false
	combat_service.get_ref().spawn_shot(i,BOLT_ID,angle,{"pos":origin,
		"speed":900.0 if heavy else (330.0 if second_phase else 280.0),
		"damage":2.0 if heavy else 1.0,"radius":shot_radius,"life":2.4,
		"cannon_blast_radius":64.0 if heavy else 28.0,
		"visual_weapon":2,"visual_variant":"boss_cannon" if heavy else "boss_shell","can_lens":false})
	if cue:
		flash_age = 0
		recoil = 1.8 if heavy else 1.0
		muzzle_angle = angle
		muzzle_angles = [angle]
		sound_requested.emit("boss_cannon" if heavy else "boss_salvo",0)
	return true

func fire_salvo(i: int, arena) -> void:
	var count := 16 if second_phase else 12
	muzzle_angles.clear()
	for n in range(count):
		var angle := attack_angle+(n+salvo_index*.5)*TAU/count
		if fire_cannon(i,arena,angle,false,false): muzzle_angles.append(angle)
	salvo_index += 1
	if not muzzle_angles.is_empty():
		flash_age = 0
		recoil = .65
		sound_requested.emit("boss_salvo",0)

func step_waves(dt: float, target, arena) -> void:
	for wave in waves:
		var old: float = wave.radius
		wave.radius += WAVE_SPEED*dt
		var old_delta: float = wave.previous.distance_to(wave.origin)-old
		var new_delta: float = target.state.pos.distance_to(wave.origin)-wave.radius
		if not wave.resolved and minf(old_delta,new_delta) <= target.radius+8 and maxf(old_delta,new_delta) >= -target.radius-8:
			wave.resolved = true # One crossing per ring, including successful dodge invulnerability.
			target.hurt(1.0,-1,false,{"kind":"boss_shockwave"},self)
		wave.previous = target.state.pos
	waves = waves.filter(func(wave): return wave.radius < arena.field_rect.size.length()+100)

func execute_attack(_i: int, target, arena) -> void:
	var delta: Vector2 = target.state.pos-state.pos
	var in_range: bool = delta.length() <= (180.0 if move_name == "slam" else 205.0)
	var in_angle: bool = move_name == "heat" or absf(wrapf(delta.angle()-attack_angle,-PI,PI)) <= .65
	if in_range and in_angle and not arena.line_blocked(state.pos,target.state.pos):
		target.hurt(1.5 if move_name == "slam" else 1.0,-1,false,{"kind":"boss_"+move_name},self)
	impact_age = 0
	impact_kind = move_name
	sound_requested.emit("boss_impact" if move_name == "slam" else "lizard_spit",0)

func enemy_visual_snapshot() -> Dictionary:
	var view := super.enemy_visual_snapshot()
	view.startup = clampf(1.0-attack_time/maxf(.01,startup_total),0,1) if attack_phase == "grace" else 1.0
	view.move_name = move_name
	view.second_phase = second_phase
	view.waves = waves.duplicate(true)
	view.position = state.pos
	view.spin_time = spin_time
	view.opening = opening
	view.lift = lift
	view.impact_age = impact_age
	view.impact_kind = impact_kind
	view.cannon_charge = clampf(1.0-(attack_time if attack_phase == "windup" else emission_time)/.6,0,1) if move_name == "cannon" and attack_phase in ["windup","cannon"] else 0.0
	view.flash_age = flash_age
	view.muzzle = Vector2.from_angle(muzzle_angle)*MUZZLE_DISTANCE
	view.muzzle_angle = muzzle_angle
	view.muzzle_angles = muzzle_angles.duplicate()
	view.recoil = recoil
	view.drive = drive
	view.particles = particles.duplicate(true)
	view.angle = attack_angle if attack_phase in ["dash","machinegun","salvo","cannon","shockwave"] else view.angle
	return view

func _draw() -> void:
	preload("res://scripts/visuals/furnace_warden_visual.gd").paint(self,enemy_visual_snapshot())

# Bounded visual particle pool, stepped by combat so focus/menu pause is exact.
func step_presentation(dt: float) -> void:
	drive = move_toward(drive,1.0 if attack_phase == "dash" else .35 if attack_phase == "windup" and move_name == "dash" else 0.0,dt*7)
	recoil = move_toward(recoil,0,dt*11)
	spin_time += dt*(3 if attack_phase == "dash" else 1.5 if second_phase else 1)
	opening = clampf((1.2-attack_time-.35)/.65,0,1) if attack_phase == "transition" else (1.0 if second_phase else 0.0)
	impact_age += dt
	flash_age += dt
	var target_lift := 32.0 if attack_phase == "windup" and move_name == "slam" else 0.0
	if attack_phase == "shockwave" and emissions_left > 0:
		var jump := clampf(1.0-emission_time/JUMP_TIME,0,1)
		lift = sin(jump*PI)*65 if emission_time <= JUMP_TIME else 0.0
	else:
		lift = move_toward(lift,target_lift,dt*(150 if target_lift > 0 else 600))
	for particle in particles:
		particle.life -= dt
		particle.pos += particle.velocity*dt
	particles = particles.filter(func(p): return p.life > 0)
	particle_clock -= dt
	if particle_clock <= 0 and (attack_phase == "dash" or second_phase):
		particle_clock = .035 if attack_phase == "dash" else .15
		if particles.size() < 48:
			particle_serial += 1
			var a := particle_serial*2.399963
			var smoke := attack_phase != "dash"
			var origin: Vector2 = state.pos+Vector2(cos(a)*35,-90 if smoke else 20)
			var velocity := Vector2(cos(a)*12,-25) if smoke else -Vector2.from_angle(attack_angle)*100+Vector2.from_angle(a)*55
			var duration := .7 if smoke else .3
			particles.append({"pos":origin,"velocity":velocity,"life":duration,"total":duration,"smoke":smoke,"size":4.0})

func chase_direction(dt: float, target: Vector2, arena) -> Vector2:
	var navigation = preload("res://scripts/ai/cpu_navigation.gd")
	if navigation.segment_clear(arena,state.pos,target,radius):
		route.clear()
		return (target-state.pos).normalized()
	route_time -= dt
	if route_time <= 0:
		route_time = .5
		route = navigation.combat_path(arena,state.pos,target,Vector2(100,500),4096,radius)
	while not route.is_empty() and state.pos.distance_to(route[0]) < 8: route.pop_front()
	if not route.is_empty(): return (route[0]-state.pos).normalized()
	# Wall sliding still works when the target lies beyond the large body's clearance.
	return (target-state.pos).normalized()
