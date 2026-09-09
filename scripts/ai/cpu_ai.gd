extends RefCounted
# Ported from the legacy web version's aiInput()/updatePlayer() CPU branch (legacy-web/dist/
# game.js). The CPU always controls player index 1 and always targets player index 0, exactly
# like legacy (mode==='cpu' hardcodes `enemy=players[0]` and the p.id===1 branch).
#
# Side effects that legacy's aiInput() performs inline (weapon auto-switch, reload-when-empty,
# dodge roll, melee, pulse/blank use, and the pickup acquire() call) are likewise applied
# directly to the player/game here. Only movement (dx,dy, pre-normalization, matching legacy's
# un-normalized accumulation before updatePlayer's shared hypot-normalize step) and the aim
# jitter/shoot decision are returned, since those still have to flow through Player.step()'s
# existing roll/movement/reload-on-shoot/can_fire() handling shared with human input.
#
# One deliberate implementation-order simplification vs. legacy: legacy decrements all of a
# player's cooldown timers (melee, dodge, roll, reload, ...) at the top of updatePlayer, before
# calling aiInput() in the same tick, so a cooldown that reaches exactly zero this frame is
# already usable when aiInput checks it. Here, decide() is called from main.gd BEFORE
# Player.step() (which owns the timer decrement), so a cooldown reaching zero this frame is
# read as still active and becomes usable on the next physics frame instead — a ~1/60s lag
# with no gameplay-visible effect, accepted to keep decide() a pure decision function that
# does not need to duplicate Player.step()'s timer bookkeeping.
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
			var g: Dictionary = Weapons.definition(item.gun)
			desired = player.inventory.size() < 4 or player.inventory.any(func(x): return x.id == item.gun and float(x.reserve) < float(g.stock)*.6) or g.rarity == "S"
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
	var strafe: float = sin(elapsed*.7)*.8
	var dx: float = cos(a)*forward + cos(a+PI/2)*strafe
	var dy: float = sin(a)*forward + sin(a+PI/2)*strafe

	# A wanted pickup within cost 500 overrides movement entirely; within 45px, take it.
	if target != null and best < 500.0:
		a = (target.position-p.pos).angle()
		dx = cos(a)
		dy = sin(a)
		if p.pos.distance_to(target.position) < 45.0:
			var force: bool = player.inventory.size() >= 4 and target.kind == "weapon" and Weapons.definition(target.gun).rarity == "S"
			game.supplies.acquire(1,target,force or target.kind == "relic")

	# Danger zone: the CPU checks a wider margin (+65/+60) than the damage margin itself
	# (+25) so it steps back in before actually taking chip damage, then heads for center.
	var inset: float = game.arena_inset()
	if inset > 0.0 and (p.pos.x < inset+65.0 or p.pos.x > 1120.0-inset-65.0 or p.pos.y < inset*.58+60.0 or p.pos.y > 600.0-inset*.58-60.0):
		a = (Vector2(560.0,300.0)-p.pos).angle()
		dx = cos(a)
		dy = sin(a)

	# Dodge the nearest enemy bullet within 90px by strafing perpendicular to it, and roll
	# once a per-CPU cooldown (randomized .35-.75s of continuous threat) expires.
	var threat = null
	for shot in game.shots:
		if shot.state.owner != 1 and not shot.state.dead and shot.state.pos.distance_to(p.pos) < 90.0:
			threat = shot
			break
	if threat != null:
		dx += -(threat.state.pos.y-p.pos.y)/65.0
		dy += (threat.state.pos.x-p.pos.x)/65.0
		p.ai_cd -= dt
		if p.ai_cd < 0.0 and p.dodge <= 0.0 and p.roll <= 0.0:
			if player.handle_key(KEY_SHIFT,1,game.shots,enemy,arena):
				for n in range(6):
					game.spawn_shot(1,0,n*TAU/6,{"kind":"dodge_nova","speed":250.0,"damage":.35,"life":1.2,"radius":4.0,"color":"#ecc5ff","can_lens":false,"depth":1})
			p.ai_cd = randf_range(.35,.75)

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

	if player.weapon().clip == 0: player.start_reload()
	if d < 64.0: player.handle_key(KEY_N,1,game.shots,enemy,arena)

	var def: Dictionary = player.definition()
	var shoot: bool = not arena.line_blocked(p.pos,enemy.state.pos) or int(def.get("bounce",0)) > 0 or bool(def.get("boomerang",false))
	return {"dx":dx,"dy":dy,"shoot":shoot,"aim_jitter":sin(elapsed*2.2)*.09}
