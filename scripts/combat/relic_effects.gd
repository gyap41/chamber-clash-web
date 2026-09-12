extends RefCounted
const Relics = preload("res://scripts/catalog/relic_catalog.gd")
# Order is part of gameplay: starter, battery, last round, then multiplicative bonuses.
static func scales(player, direct: bool) -> Vector2:
	return Vector2((1.0+Relics.additive_bonus(player.relics,"shot_bonus") if direct else 1.0)*(1.0+player.relic_value(6,"heavy_bonus")),(1.0+Relics.additive_bonus(player.relics,"speed_bonus") if direct else 1.0)*player.relic_value(6,"heavy_ratio"))
static func shooting(player, g: Dictionary, w: Dictionary, scatter: bool, count: int, burst_count: int) -> Dictionary:
	var first_shot: bool = w.clip == int(g.mag)
	var shot_damage: float = (.5 if scatter else g.damage) * (1.0+player.relic_value(7,"starter_bonus") if first_shot else 1.0)
	# 帰還バッテリー: a charge armed by the *previous* weapon switch boosts this volley once,
	# then clears itself; it cannot re-arm until another boomerang recovery + switch happens.
	if 14 in player.relics and player.state.get("return_battery_armed", false):
		# One charge belongs to the shot, shared across pellets rather than multiplied by count.
		shot_damage += float(Relics.definition(14).get("battery_bonus",.45))/(count*burst_count)
		player.state.return_battery_armed = false
	var echo_damage := shot_damage
	if w.clip == 1 and 22 in player.relics:
		shot_damage += player.relic_value(22,"last_bonus")/(count*burst_count)
	var damage_scale: float = scales(player,true).x
	var speed_scale: float = scales(player,true).y
	if 30 in player.relics and player.state.sight_time > 0:
		speed_scale *= 1.0+player.relic_value(30,"sight_bonus")
		player.state.sight_time = 0.0
	return {"first":first_shot,"damage":shot_damage,"echo_damage":echo_damage,"damage_scale":damage_scale,"speed_scale":speed_scale}

# One direct projectile can trigger the first-bounce generation once; derived shots cannot.
static func first_bounce(projectile, previous: Vector2) -> void:
	var b: Dictionary = projectile.state
	var source_player = projectile.source_player
	if b.rebounds == 1 and 11 in source_player.relics: b.velocity *= 1.0+source_player.relic_value(11,"rebound_bonus")
	if b.rebounds == 1 and b.depth == 0 and 31 in source_player.relics: projectile.damage *= 1.0+source_player.relic_value(31,"rubber_bonus")
	# 反響の種: the *first* bounce of a directly-fired bullet drops a short-lived
	# stationary pool at the bounce point. "echo_seed" in applied_effects makes this
	# resilient even if rebounds==1 could somehow be re-entered; b.depth==0 keeps the
	# pool itself (and any other derived bullet) from ever chaining another one.
	if b.rebounds == 1 and b.depth == 0 and 12 in source_player.relics and "echo_seed" not in b.applied_effects:
		b.applied_effects.append("echo_seed")
		projectile.derived_shot_requested.emit(b.owner,previous,12)

# Full reload completion is distinct from one-round reserve top-ups.
static func reload_completed(player, amount: int, w: Dictionary) -> void:
	var state: Dictionary = player.state
	if amount > 0 and 23 in player.relics and state.cool_grip_cd <= 0:
		state.dodge = maxf(0.0,state.dodge-player.relic_value(23,"cool_reduction"))
		state.cool_grip_cd = player.relic_value(23,"cool_reuse")
	if amount > 0 and player.definition().get("switcher", false): w.mode = 1-w.mode
	# 空薬莢の祝福: only a reload that both started from empty AND actually completed here
	# (not interrupted — an interrupted reload never reaches finish_reload(), see the
	# reload_slot guard above, and 予備マガジン's 1-round top-up never goes through
	# start_reload()/finish_reload() at all) charges the next full-magazine shot.
	if state.reload_started_empty and 13 in player.relics: state.empty_casing_charge = true

# Damage guards run after dodge/volley immunity and before HP subtraction.
static func incoming_damage(player, amount: float, volley: int, hazard: bool) -> float:
	var state: Dictionary = player.state
	if not hazard and 3 in player.relics and state.shield <= 0:
		state.blocked_volley = volley
		state.last_volley = -1
		state.shield = 12.0
		state.inv = .3
		player.ring_requested.emit(state.pos,Color("ffe2a0"),65.0)
		player.sound_requested.emit("bell",0)
		return 0.0
	if not hazard and 27 in player.relics and state.shell_time > 0:
		state.shell_time = 0.0
		amount = maxf(0.0,amount-player.relic_value(27,"shell_reduction"))
		if amount <= 0: return 0.0
	return amount

static func damaged(player, actual: float, hazard: bool) -> void:
	var state: Dictionary = player.state
	if not hazard and actual > 0 and state.hp > 0 and 28 in player.relics and state.aid_time <= 0 and state.aid_used < int(player.relic_value(28,"aid_limit")):
		state.aid_used += 1
		state.aid_time = player.relic_value(28,"aid_delay")

static func switching(player) -> void:
	var state: Dictionary = player.state
	if player.has_weapon() and 8 in player.relics and state.holster <= 0:
		var old: Dictionary = player.weapon()
		var old_def: Dictionary = player.resolved_definition(old.id)
		if old.reserve > 0 and old.clip < int(old_def.mag):
			old.clip += 1
			old.reserve -= 1
			state.holster = 1.5
	# 残響ホルスター: on a genuine switch (guarded by the same index==state.gun no-op check
	# above), reserve a weak follow-up shot from the *outgoing* weapon while it is still
	# `player.weapon()`. Consumes 1 round from the outgoing weapon's own ammo (clip first, then
	# reserve); an outgoing weapon with no ammo left simply misfires ("空なら不発") but the
	# cooldown still starts, so rapid switching cannot spam the request. main.gd turns this
	# into a delayed_shots entry (depth 1, no volley, can't re-trigger further generation) and
	# already clears the *enemy's* delayed shots on pulse via the existing owner filter, so a
	# pulse also removes any echo-holster shot the pulsing player had reserved against them.
	if player.has_weapon() and 16 in player.relics and state.echo_holster_cd <= 0:
		var outgoing: Dictionary = player.weapon()
		var outgoing_def: Dictionary = player.resolved_definition(outgoing.id)
		var relic16 := Relics.definition(16)
		state.echo_holster_cd = float(relic16.get("holster_cooldown",2.5))
		if int(outgoing.clip)+int(outgoing.reserve) > 0:
			if outgoing.clip > 0: outgoing.clip -= 1
			else: outgoing.reserve -= 1
			player.delayed_shot_requested.emit({"gun":outgoing.id,"angle":state.angle,"delay":.22,"damage":float(outgoing_def.damage)*float(relic16.get("holster_ratio",.5)),"kind":"echo_holster","can_lens":false,"depth":1})
	# 帰還バッテリー: a stored charge arms on the switch itself; the bonus is spent by the
	# *next* fire() call (see main.gd), not by this switch.
	if 14 in player.relics and state.return_battery_charge:
		state.return_battery_charge = false
		state.return_battery_armed = true
	if player.has_weapon() and 30 in player.relics and state.sight_cd <= 0:
		state.sight_time = player.relic_value(30,"sight_duration")
		state.sight_cd = player.relic_value(30,"sight_reuse")

static func melee_cleared(player, removed: int) -> void:
	var p: Dictionary = player.state
	if removed > 0 and 10 in player.relics: p.dodge = maxf(0,p.dodge-.3)
	# 余熱コンデンサ: melee that clears at least one bullet charges a bonus pellet for the next
	# shot. removed>0 can only become true once per try_melee() call, so this is naturally
	# "once per swing"; the flag itself caps the charge at one (no stacking).
	if removed > 0 and 15 in player.relics: p.residual_heat_charge = true
	if removed > 0 and 27 in player.relics and p.shell_cd <= 0:
		p.shell_time = player.relic_value(27,"shell_duration")
		p.shell_cd = player.relic_value(27,"shell_reuse")

static func recovered(player, id: int) -> void:
	var state: Dictionary = player.state
	if 14 in player.relics: state.return_battery_charge = true
	if 33 in player.relics and state.reel_cd <= 0 and player.top_up_weapon(id):
		state.reel_cd = player.relic_value(33,"reel_reuse")

static func dodge_started(player) -> bool:
	player.state.phase_load_used = false
	return 5 in player.relics
static func pulse_used(player) -> void:
	if 29 in player.relics: player.state.boots_time = player.relic_value(29,"boots_duration")
