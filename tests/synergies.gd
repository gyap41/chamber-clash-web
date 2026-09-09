extends SceneTree
# P3: common trigger dispatch + the 6 new synergy relics (12-17). Individual triggers,
# a couple of representative combinations, and the anti-recursion/no-double-multiplier
# invariants (depth==0 gate, applied_effects audit trail, one-shot charge flags).
func _initialize() -> void:
	call_deferred("run")

# battle.gd's start(game,1) always gives BOTH players inventory [sidearm(0), candy(1)] with
# candy(1) equipped (build.main defaults to weapon 1 for both sides). id==0 switches back to
# the already-owned sidearm; id==1 leaves candy equipped; any other id adds and equips a THIRD
# weapon (must not already be 0/1, and must not already be owned).
func setup(game, id: int) -> void:
	game.reset_round()
	preload("res://tests/helpers/battle.gd").start(game,1)
	var p = game.players[0]
	if id == 0: p.equip_slot(0)
	elif id != 1: assert(p.add_gun(id))
	p.state.shot = 0.0
	p.state.pos = Vector2(170,100)
	p.state.angle = 0.0
	game.players[1].state.pos = Vector2(950,500)

func key_event(code: int) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	event.echo = false
	return event

# Catalog base damage for a weapon id (pre any relic multiplier), so the return-battery test
# can assert the flat bonus was added exactly once without hardcoding the pistol's damage twice.
func g_damage(game, id: int) -> float:
	return game.catalog.guns[id].damage

func run() -> void:
	var game = load("res://scenes/game/main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	var p = game.players[0]
	var q = game.players[1]

	# --- 反響の種 (12): first wall bounce of a depth-0 bullet drops one stationary pool. ---
	setup(game,1) # 跳弾キャンディ (already the equipped weapon after setup(game,1)): bounce:2.
	assert(p.add_relic(12))
	game.fire(0)
	var bounced = game.shots[-1]
	assert(bounced.state.bounce == 2 and bounced.state.depth == 0)
	var before_bounce: int = game.shots.size()
	bounced.state.pos = Vector2(1087,100)
	bounced.state.velocity = Vector2(370,0)
	bounced.step(.02,game.arena,q)
	assert(bounced.state.rebounds == 1 and "echo_seed" in bounced.state.applied_effects)
	assert(game.shots.size() == before_bounce+1) # exactly one pool spawned
	var pool = game.shots[-1]
	assert(pool.state.velocity == Vector2.ZERO and pool.state.depth == 1 and pool.state.owner == 0)
	# A second bounce of the SAME bullet must not spawn a second pool (guarded by "echo_seed"
	# already being in applied_effects, independent of the rebounds==1 check re-firing).
	bounced.state.pos = Vector2(1087,100)
	bounced.state.velocity = Vector2(370,0)
	bounced.step(.02,game.arena,q)
	assert(bounced.state.rebounds == 2)
	assert(game.shots.size() == before_bounce+1) # still just the one pool
	# A derived (depth>0) bullet bouncing must never chain a second seed, even with the relic
	# equipped and its own first bounce ("派生効果は原則さらに別の生成効果を発動しない").
	game.spawn_shot(0,1,0.0,{"pos":Vector2(1087,100),"depth":1})
	var derived_bullet = game.shots[-1]
	assert(derived_bullet.state.depth == 1)
	var shots_before_derived: int = game.shots.size()
	derived_bullet.state.velocity = Vector2(370,0)
	derived_bullet.step(.02,game.arena,q)
	assert(derived_bullet.state.rebounds == 1 and game.shots.size() == shots_before_derived) # no new pool

	# --- 空薬莢の祝福 (13): reload-from-empty charges the next full-magazine shot only. ---
	setup(game,0)
	assert(p.add_relic(13))
	p.weapon().clip = 3 # not empty: this reload must NOT set the charge
	p.start_reload()
	assert(not p.state.reload_started_empty)
	p.step(p.state.reload+.01,0,q,game.arena)
	assert(not p.state.empty_casing_charge)
	p.weapon().clip = 0
	p.start_reload()
	assert(p.state.reload_started_empty)
	p.step(p.state.reload+.01,0,q,game.arena)
	assert(p.state.empty_casing_charge and p.weapon().clip == p.definition().mag)
	var shots_before_casing: int = game.shots.size()
	game.fire(0) # full magazine -> first_shot true -> bonus pellet, charge consumed
	assert(not p.state.empty_casing_charge)
	assert(game.shots.size() == shots_before_casing+2) # the normal shot + the bonus pellet
	assert(game.shots[-1].state.depth == 1 and is_equal_approx(game.shots[-1].damage,.5))
	shots_before_casing = game.shots.size()
	p.state.shot = 0.0 # bypass the fire-rate cooldown so this second shot is not silently skipped
	game.fire(0) # charge already spent: no extra pellet on the next shot
	assert(game.shots.size() == shots_before_casing+1)
	# An interrupted reload (switching weapons mid-reload) never reaches finish_reload(), so it
	# can never charge the bonus either.
	setup(game,0)
	assert(p.add_relic(13))
	p.weapon().clip = 0
	p.start_reload()
	assert(p.state.reload_started_empty)
	p.equip_slot(1) # switching cancels the reload in progress
	p.step(.01,0,q,game.arena) # reload_slot no longer matches state.gun; finish_reload() no-ops
	assert(not p.state.empty_casing_charge)

	# --- 帰還バッテリー (14): only an actual boomerang recovery charges it; hits/expiry don't. ---
	setup(game,5) # ムーンリーパー: boomerang.
	assert(p.add_relic(14))
	game.fire(0)
	var moon = game.shots[-1]
	assert(moon.state.boomerang and moon.state.depth == 0)
	moon.state.age = 1.0
	moon.state.pos = p.state.pos + Vector2(10,0) # within the 20px return radius
	moon.step(.02,game.arena,q)
	assert(moon.state.life == 0.0 and p.state.return_battery_charge)
	# A hit does not count as recovery.
	setup(game,5)
	assert(p.add_relic(14))
	game.fire(0)
	moon = game.shots[-1]
	moon.state.age = 1.0
	moon.state.pos = q.state.pos # far from the owner, but on top of the enemy: a hit, not a return
	moon.step(.02,game.arena,q)
	assert(not p.state.return_battery_charge)
	# Natural life expiry (never gets close enough to return) does not count either.
	setup(game,5)
	assert(p.add_relic(14))
	game.fire(0)
	moon = game.shots[-1]
	moon.state.life = .001
	moon.step(.01,game.arena,q)
	assert(moon.state.life <= 0 and not p.state.return_battery_charge)
	# Charge arms on switch, is spent by exactly the next fire() call, then clears.
	setup(game,5)
	assert(p.add_relic(14))
	p.state.return_battery_charge = true
	p.equip_slot(1) # switch from moonreaper (slot 2) back to candy (slot 1, already owned)
	assert(p.state.return_battery_armed and not p.state.return_battery_charge)
	p.state.shot = 0.0 # equip_slot() itself sets a .15s switch cooldown; bypass it so this fire() isn't silently skipped
	game.fire(0)
	assert(is_equal_approx(game.shots[-1].damage,g_damage(game,1)+.45))
	assert(not p.state.return_battery_armed)
	var damage_before: float = game.shots[-1].damage
	p.state.shot = 0.0 # bypass the fire-rate cooldown so this second shot is not silently skipped
	game.fire(0) # bonus already spent: normal damage this time
	assert(not is_equal_approx(game.shots[-1].damage,damage_before))

	# --- 余熱コンデンサ (15): melee clearing a bullet charges one bonus pellet, once per swing. ---
	setup(game,0)
	assert(p.add_relic(15))
	game.spawn_shot(1,0,0.0,{})
	game.shots[-1].state.pos = Vector2(p.state.pos.x+40,p.state.pos.y)
	p.try_melee(0,game.shots,q,game.arena)
	assert(p.state.residual_heat_charge)
	var shots_before_heat: int = game.shots.size()
	p.state.shot = 0.0 # try_melee() itself sets a .3s shot cooldown (p.shot = maxf(p.shot,.3)); bypass it so this fire() isn't silently skipped
	game.fire(0)
	assert(not p.state.residual_heat_charge)
	assert(game.shots.size() == shots_before_heat+2) # normal shot + bonus pellet
	shots_before_heat = game.shots.size()
	p.state.shot = 0.0 # bypass the fire-rate cooldown so this second shot is not silently skipped
	game.fire(0) # charge already spent
	assert(game.shots.size() == shots_before_heat+1)
	# A swing that clears nothing never charges it.
	setup(game,0)
	assert(p.add_relic(15))
	p.try_melee(0,game.shots,q,game.arena)
	assert(not p.state.residual_heat_charge)

	# --- 残響ホルスター (16): switching reserves a weak follow-up from the OUTGOING weapon. ---
	setup(game,0)
	assert(p.add_relic(16))
	var outgoing_reserve: int = p.inventory[0].reserve
	var outgoing_clip: int = p.inventory[0].clip
	p.equip_slot(1) # switch away from slot 0 (weapon id 0) while it still has ammo
	assert(game.delayed_shots.size() == 1)
	var reserved: Dictionary = game.delayed_shots[0]
	assert(reserved.gun == 0 and reserved.kind == "echo_holster" and reserved.depth == 1 and not reserved.can_lens)
	assert(p.inventory[0].clip == outgoing_clip-1 or p.inventory[0].reserve == outgoing_reserve-1)
	assert(p.state.echo_holster_cd > 0.0)
	var cd_before: float = p.state.echo_holster_cd
	p.equip_slot(0) # cooldown still active: no second reservation
	assert(game.delayed_shots.size() == 1)
	game._physics_process(.001) # advance the cooldown timer
	assert(p.state.echo_holster_cd < cd_before)
	# A pulse from the OPPOSING player clears an already-reserved echo-holster shot (reuses the
	# existing delayed_shots owner filter - "パルスは敵の新しい追射予約も消去する").
	setup(game,0)
	assert(p.add_relic(16))
	p.equip_slot(1)
	assert(game.delayed_shots.size() == 1 and game.delayed_shots[0].owner == 0)
	q.state.pulses = 1
	game.use_pulse(1)
	assert(game.delayed_shots.is_empty())
	# An outgoing weapon with no ammo left misfires (no delayed shot) but the cooldown still starts.
	setup(game,0)
	assert(p.add_relic(16))
	p.inventory[0].clip = 0
	p.inventory[0].reserve = 0
	p.equip_slot(1)
	assert(game.delayed_shots.is_empty() and p.state.echo_holster_cd > 0.0)

	# --- すり抜け装填 (17): a nearby enemy bullet during a dodge loads 1 round, once per dodge. ---
	setup(game,0)
	assert(p.add_relic(17))
	p.inventory[0].clip = 5
	p.inventory[0].reserve = 10
	p.state.roll = .2 # mid-dodge
	game.spawn_shot(1,0,0.0,{})
	game.shots[-1].state.pos = p.state.pos + Vector2(10,0) # well within phase_radius (42px)
	game._physics_process(.001)
	assert(p.inventory[0].clip == 6 and p.inventory[0].reserve == 9)
	assert(p.state.phase_load_used)
	# Bypasses the reload machinery entirely, so it never charges 空薬莢の祝福 even if both
	# relics are equipped.
	assert(p.add_relic(13))
	assert(not p.state.empty_casing_charge and not p.state.reload_started_empty)
	var clip_before: int = p.inventory[0].clip
	game.spawn_shot(1,0,0.0,{})
	game.shots[-1].state.pos = p.state.pos + Vector2(10,0)
	game._physics_process(.001) # already used this dodge: no second load
	assert(p.inventory[0].clip == clip_before)
	# A fresh dodge resets the once-per-dodge guard.
	p.state.roll = 0
	p.state.dodge = 0
	game._unhandled_key_input(key_event(KEY_SPACE))
	assert(not p.state.phase_load_used)

	print("PASS: echo seed bounce/no-recursion, empty casing charge/interrupted reload, return battery recovery-only/switch-arm, residual heat charge, echo holster ammo/cooldown/pulse-clear, phase load once-per-dodge/no-reload-trigger")
	game.queue_free()
	quit()
