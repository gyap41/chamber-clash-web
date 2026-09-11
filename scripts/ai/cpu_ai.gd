extends RefCounted
# CPU controls P2 through shared player actions and cooldowns. Movement and aim
# feed Player.step(); roll, melee, reload and pickups use the normal gameplay APIs.
# Combat timers tick in Player.step after decide, so newly ready actions may wait one frame.
const Weapons = preload("res://scripts/catalog/weapon_catalog.gd")

static func decide(game, player, enemy, dt: float) -> Dictionary:
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
		if switch_index >= 0: player.request_switch(switch_index)

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

	# Base movement: close the distance past 340px, back off under 200px, hold and strafe
	# in between. The strafe term oscillates with match time, not with either player's state.
	var to_enemy: Vector2 = enemy.state.pos - p.pos
	var d: float = to_enemy.length()
	var a: float = to_enemy.angle()
	var forward: float = 1.0 if d > 340.0 else (-1.0 if d < 200.0 else 0.0)
	if not player.has_weapon(): forward = 1.0 if d > 45.0 else 0.0
	var strafe: float = sin(elapsed*.7)*.8
	var dx: float = cos(a)*forward + cos(a+PI/2)*strafe
	var dy: float = sin(a)*forward + sin(a+PI/2)*strafe

	# A wanted pickup within cost 500 overrides movement entirely; within 45px, take it.
	if target != null and best < 500.0:
		a = (target.position-p.pos).angle()
		dx = cos(a)
		dy = sin(a)
		if p.pos.distance_to(target.position) < 45.0:
			if target.kind in ["weapon","relic"]:
				# P7 宝箱演出：CPUも人間と同じ開封待ち（supplies.step()のchest_open_duration）に
				# 従う。横取り禁止ルールも共通（interact()と同じopening_playerの判定）。age条件も
				# interact()と揃え、スポーン直後の無敵猶予（pickup_delay）中は開封を開始しない。
				# CPUはtargetを再選定するたびにこの45px判定を通るため、開封中も自然にその場へ
				# 留まり続け、追加の「待機」ロジックは不要。
				if target.age >= game.supplies.pickup_delay and (target.opening_player == -1 or target.opening_player == 1):
					target.opening_player = 1
			else:
				game.supplies.acquire(1,target)

	# Danger zone: the CPU checks a wider margin (+65/+60) than the damage margin itself
	# (+25) so it steps back in before actually taking chip damage, then heads for center.
	var inset: float = game.arena_inset()
	if inset > 0.0 and (p.pos.x < inset+65.0 or p.pos.x > 1120.0-inset-65.0 or p.pos.y < inset*.58+60.0 or p.pos.y > 600.0-inset*.58-60.0):
		a = (Vector2(560.0,300.0)-p.pos).angle()
		dx = cos(a)
		dy = sin(a)

	# Predict closest approach, ignoring receding bullets and shots behind cover.
	# Timers recover even while no bullet is nearby.
	p.ai_cd = maxf(0.0,p.ai_cd-dt)
	var threat = null
	var soonest := INF
	for shot in game.shots:
		if shot.state.owner == 1 or shot.state.dead: continue
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
			if shot.state.owner == 0 and not shot.state.dead and shot.state.pos.distance_to(p.pos) < 120.0: nearby += 1
		if nearby > 5: game.use_pulse(1)

	# If the chosen direction would walk into a wall, try turning 90 degrees either way or
	# fully around and take the first candidate that's actually clear.
	if arena.solid(p.pos+Vector2(dx,dy)*40.0,18.0):
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
		p.dir = Vector2(dx,dy).normalized()
		if player.handle_key(KEY_SHIFT,1,game.shots,enemy,arena):
			for n in range(6):
				game.spawn_shot(1,0,n*TAU/6,{"kind":"dodge_nova","speed":250.0,"damage":.35,"life":1.2,"radius":4.0,"color":"#ecc5ff","can_lens":false,"depth":1})
		p.ai_cd = randf_range(.35,.75)
	if player.has_weapon() and player.weapon().clip == 0: player.start_reload()
	p.angle = to_enemy.angle()
	if d < 64.0: player.handle_key(KEY_N,1,game.shots,enemy,arena)

	# P8z：武器を1丁も置かなかったラウンドは丸腰になりうる。撃てないので射線を取りに行っても
	# 意味がなく、近接の間合いへ詰めるのが唯一の攻め手になる。
	if not player.has_weapon():
		return {"dx":dx,"dy":dy,"shoot":false,"aim_jitter":sin(elapsed*2.2)*.09}
	var def: Dictionary = player.definition()
	var shoot: bool = not arena.line_blocked(p.pos,enemy.state.pos) or int(def.get("bounce",0)) > 0 or bool(def.get("boomerang",false))
	var aim: Vector2 = predicted_target(p,enemy,def,dt,arena)
	if arena.line_blocked(p.pos,aim): aim = enemy.state.pos
	return {"dx":dx,"dy":dy,"shoot":shoot,"aim_jitter":wrapf((aim-p.pos).angle()-to_enemy.angle(),-PI,PI)+sin(elapsed*2.2)*.035}

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
