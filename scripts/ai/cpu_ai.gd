extends RefCounted
# Each CPU produces common commands for its own participant and a roster-selected enemy.
# sample updates decision memory only; action effects belong to CombatSession.
# Combat timers tick in Player.step after decisions, retaining the existing order.
const Weapons = preload("res://scripts/catalog/weapon_catalog.gd")
const Navigation = preload("res://scripts/ai/cpu_navigation.gd")

static func decide(game, player, enemy, dt: float) -> Dictionary:
	var command := sample(game,player,enemy,dt)
	game.apply_command(game.players.find(player),command)
	return command

static func sample(game, player, enemy, dt: float) -> Dictionary:
	var command := preload("res://scripts/combat/combat_command.gd").idle(player.state.angle)
	if enemy == null or player.state.hp <= 0: return command
	var index: int = game.players.find(player)
	var p: Dictionary = player.state
	var arena = game.arena
	var elapsed: float = game.round_duration - game.remaining

	# If the active weapon is completely dry (no clip, no reserve), switch to the first one
	# in inventory that still has ammo.
	var w: Dictionary = player.weapon()
	if int(w.clip)+int(w.reserve) == 0:
		var switch_index := -1
		for n in range(player.inventory.size()):
			var slot: Dictionary = player.inventory[n]
			if int(slot.clip)+int(slot.reserve) > 0:
				switch_index = n
				break
		if switch_index >= 0: command.switch = switch_index

	# Pick the closest pickup the CPU actually wants; S-rarity weapons are weighted as if 35%
	# closer so the CPU will detour further to grab one.
	var target = null
	var best := INF
	for item in game.supplies.items:
		if item.used: continue
		var desired: bool
		if item.kind == "ammo":
			desired = player.inventory.any(func(x): return float(x.reserve) < float(Weapons.definition(x.id).stock)*.6)
		elif item.kind == "relic":
			desired = player.field_relic_reason(item.gun) == ""
		else:
			desired = player.field_weapon_reason(item.gun).is_empty()
		if not desired: continue
		var cost: float = p.pos.distance_to(item.position) * (.65 if item.kind == "weapon" and Weapons.definition(item.gun).rarity == "S" else 1.0)
		if cost < best:
			best = cost
			target = item

	# Use the currently equipped definition (including mods and switcher mode).
	var band := combat_range(player,int(command.switch))
	var to_enemy: Vector2 = enemy.state.pos - p.pos
	var d: float = to_enemy.length()
	var a: float = to_enemy.angle()
	var forward: float = 1.0 if d > band.y else (-1.0 if d < band.x else 0.0)
	var strafe: float = sin(elapsed*.7)*.8
	var dx: float = cos(a)*forward + cos(a+PI/2)*strafe
	var dy: float = sin(a)*forward + sin(a+PI/2)*strafe
	var route := combat_direction(arena,p,enemy.state.pos,band,Vector2(dx,dy),dt)
	if not route.is_zero_approx():
		dx = route.x
		dy = route.y

	# A wanted pickup within cost 500 overrides movement entirely; within 45px, take it.
	if target != null and best < 500.0:
		a = (target.position-p.pos).angle()
		dx = cos(a)
		dy = sin(a)
		if p.pos.distance_to(target.position) < 45.0: command.interact = true

	# Predict closest approach, ignoring receding bullets and shots behind cover.
	# Timers recover even while no bullet is nearby.
	p.ai_cd = maxf(0.0,p.ai_cd-dt)
	var threat = null
	var soonest := INF
	for shot in game.shots:
		if not game.roster.hostile(index,shot.state.owner) or shot.state.dead: continue
		var offset: Vector2 = p.pos-shot.state.pos
		var velocity: Vector2 = shot.state.velocity
		var approach := 0.0
		if velocity.length_squared() > 1.0:
			approach = offset.dot(velocity)/velocity.length_squared()
			if approach < 0.0 or approach > .4: continue
		elif offset.length() > 35.0:
			continue
		if (offset-velocity*approach).length() > player.radius+shot.radius+18.0: continue
		if arena.line_blocked(shot.state.pos,p.pos): continue
		if approach < soonest:
			soonest = approach
			threat = shot
	if threat != null:
		var heading: Vector2 = threat.state.velocity.normalized()
		if heading.is_zero_approx(): heading = (p.pos-threat.state.pos).normalized()
		var evade := Vector2(-heading.y,heading.x)
		if evade.dot(Vector2(dx,dy)) < 0: evade = -evade
		dx += evade.x*2.0
		dy += evade.y*2.0

	# Panic-pulse when swarmed by more than 5 of the enemy's own bullets within 120px.
	if p.pulses > 0:
		var nearby := 0
		for shot in game.shots:
			if game.roster.hostile(index,shot.state.owner) and not shot.state.dead and shot.state.pos.distance_to(p.pos) < 120.0: nearby += 1
		if nearby > 5: command.pulse = true

	# Retreat wins over pickups, kiting and outward bullet steering until well inside.
	var escape := escape_direction(game,p)
	if not escape.is_zero_approx():
		dx = escape.x
		dy = escape.y

	# If the chosen direction would walk into a wall, try turning 90 degrees either way or
	# fully around and take the first candidate that's actually clear.
	if escape.is_zero_approx() and arena.solid(p.pos+Vector2(dx,dy)*40.0,18.0):
		var base: float = Vector2(dx,dy).angle()
		for turn in [PI/2,-PI/2,PI]:
			var candidate: Vector2 = Vector2.from_angle(base+turn)
			if not arena.solid(p.pos+candidate*45.0,18.0):
				dx = candidate.x
				dy = candidate.y
				break

	# Start the roll only after wall avoidance and set its direction before handle_key.
	# Player.step deliberately preserves p.dir during a roll.
	if threat != null and p.ai_cd <= 0.0 and p.dodge <= 0.0 and p.roll <= 0.0:
		command.dodge = true
		p.ai_cd = randf_range(.35,.75)
	command.reload = player.has_weapon() and (player.inventory[command.switch].clip if command.switch >= 0 else player.weapon().clip) == 0
	command.melee = d < 64.0
	command.dx = dx
	command.dy = dy
	command.angle = to_enemy.angle()

	# P8z：武器を1丁も置かなかったラウンドは丸腰になりうる。撃てないので射線を取りに行っても
	# 意味がなく、近接の間合いへ詰めるのが唯一の攻め手になる。
	if not player.has_weapon():
		command.aim_jitter = sin(elapsed*2.2)*.09
		command.angle += command.aim_jitter
		return command
	var def: Dictionary = player.resolved_definition(player.inventory[command.switch].id) if command.switch >= 0 else player.definition()
	var shoot: bool = not arena.line_blocked(p.pos,enemy.state.pos) or int(def.get("bounce",0)) > 0 or bool(def.get("boomerang",false))
	var aim: Vector2 = predicted_target(p,enemy,def,dt,arena)
	if arena.line_blocked(p.pos,aim): aim = enemy.state.pos
	command.shoot = shoot
	command.aim_jitter = wrapf((aim-p.pos).angle()-to_enemy.angle(),-PI,PI)+sin(elapsed*2.2)*.035
	command.angle += command.aim_jitter
	return command

static func predicted_target(p: Dictionary, enemy, def: Dictionary, dt: float, arena) -> Vector2:
	# Infer motion from observed positions, never from human input. Clamp teleports/rolls
	# and the prediction horizon so changes of direction still let the human dodge.
	var current: Vector2 = enemy.state.pos
	var previous: Vector2 = p.get("ai_enemy_pos",current)
	p.ai_enemy_pos = current
	var velocity := ((current-previous)/maxf(dt,.001)).limit_length(enemy.effective_move_speed())
	var speed := float(def.get("speed",0.0))
	if speed <= 0.0 or def.get("seed",false) or def.get("bubble",false): return current
	var flight := minf(.45,p.pos.distance_to(current)/speed)
	var predicted := current+velocity*flight*.8
	predicted = predicted.clamp(arena.fighter_bounds.position,arena.fighter_bounds.end)
	return current if arena.line_blocked(current,predicted) else predicted

static func escape_direction(game, p: Dictionary) -> Vector2:
	var inset: float = game.arena_inset()
	var safe: Rect2 = game.arena.safe_rect(inset,Vector2(65,60))
	var inner := safe.grow(-40.0)
	if inset <= 0.0 or inner.has_point(p.pos):
		p.ai_retreat = false
		p.ai_escape_path = []
		return Vector2.ZERO
	if not safe.has_point(p.pos): p.ai_retreat = true
	if not p.get("ai_retreat",false): return Vector2.ZERO
	var path: Array = p.get("ai_escape_path",[])
	while not path.is_empty() and p.pos.distance_to(path[0]) < 6.0: path.pop_front()
	var direction: Vector2 = (game.arena.field_rect.get_center()-p.pos).normalized() if path.is_empty() else (path[0]-p.pos).normalized()
	var probe: Vector2 = p.pos+direction*45.0 if path.is_empty() else path[0]
	if not escape_segment_clear(game.arena,p.pos,probe):
		path = escape_path(game.arena,p.pos,inner)
		if not path.is_empty(): direction = (path[0]-p.pos).normalized()
	p.ai_escape_path = path
	return direction

static func escape_segment_clear(arena, from: Vector2, to: Vector2) -> bool:
	return Navigation.segment_clear(arena,from,to)

static func combat_range(player, slot: int = -1) -> Vector2:
	if not player.has_weapon(): return Vector2(0,45)
	var entry: Dictionary = player.inventory[slot] if slot >= 0 else player.weapon()
	var def: Dictionary = player.resolved_definition(entry.id)
	if def.get("type","") == "SHOTGUN" or (def.get("switcher",false) and entry.mode == 1):
		return Vector2(90,170)
	if def.get("seed",false):
		# Seeds stop after .6s; include the muzzle offset and part of the sensor radius.
		var reach := 24.0+float(def.speed)*.6
		return Vector2(maxf(100,reach-50),reach+float(def.get("seed_trigger_radius",100))*.5)
	if def.get("split",false) or def.get("clover",false):
		var reach := 24.0+float(def.speed)*(.68 if def.get("split",false) else .8)
		return Vector2(maxf(100,reach-45),reach+45)
	if def.get("boomerang",false): return Vector2(160,280)
	if def.get("bubble",false): return Vector2(180,300)
	# Wide multi-projectile fans still benefit from medium range, even with rail speed.
	if int(def.get("count",1)) <= 1 and (def.get("rail",false) or float(def.speed) >= 620):
		return Vector2(300,460)
	return Vector2(200,340)

static func combat_direction(arena, p: Dictionary, enemy: Vector2, band: Vector2, move: Vector2, dt: float) -> Vector2:
	var path: Array = p.get("ai_combat_path",[])
	var cooldown: float = maxf(0.0,float(p.get("ai_path_cd",0.0))-dt)
	while not path.is_empty() and p.pos.distance_to(path[0]) < 6.0: path.pop_front()
	var blocked: bool = arena.line_blocked(p.pos,enemy)
	var movement_blocked := not move.is_zero_approx() and not Navigation.segment_clear(arena,p.pos,p.pos+move.normalized()*45.0)
	if not blocked and (Navigation.firing_position(arena,p.pos,enemy,band) or (path.is_empty() and not movement_blocked)):
		p.ai_combat_path = []
		p.ai_path_cd = cooldown
		return Vector2.ZERO
	var stale: bool = p.get("ai_path_band",Vector2.ZERO) != band or enemy.distance_to(p.get("ai_path_enemy",enemy)) > 64.0
	if not path.is_empty() and not Navigation.segment_clear(arena,p.pos,path[0]): stale = true
	if stale: path = []
	# Cache successful routes until invalidated. Failed searches wait .6s before retrying.
	if cooldown <= 0.0 and (path.is_empty() or not Navigation.firing_position(arena,path.back(),enemy,band)):
		path = Navigation.combat_path(arena,p.pos,enemy,band)
		p.ai_path_enemy = enemy
		p.ai_path_band = band
		cooldown = .6
	p.ai_combat_path = path
	p.ai_path_cd = cooldown
	return Vector2.ZERO if path.is_empty() else (path[0]-p.pos).normalized()

# Small four-neighbour search only when retreat meets an obstacle. Keep the route
# between frames so the CPU cannot alternate left/right against the same corner.
static func escape_path(arena, start: Vector2, goal: Rect2) -> Array:
	var frontier: Array[Vector2i] = [Vector2i.ZERO]
	var previous := {Vector2i.ZERO: Vector2i.ZERO}
	var cursor := 0
	while cursor < frontier.size():
		var cell := frontier[cursor]
		cursor += 1
		var point := start+Vector2(cell)*32.0
		if goal.has_point(point):
			var path: Array = []
			while cell != Vector2i.ZERO:
				path.push_front(start+Vector2(cell)*32.0)
				cell = previous[cell]
			return path
		for offset in [Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT,Vector2i.UP]:
			var next: Vector2i = cell+offset
			if previous.has(next): continue
			if not escape_segment_clear(arena,point,start+Vector2(next)*32.0): continue
			previous[next] = cell
			frontier.append(next)
	return []
