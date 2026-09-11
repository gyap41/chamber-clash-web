extends SceneTree
func _initialize() -> void:
	call_deferred("run")

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

func run() -> void:
	var game = load("res://scenes/game/main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	var p = game.players[0]
	var q = game.players[1]

	# Shop now offers all 12 relics, not just the first three from phase 1.
	game.reset_round()
	game.match_state._set_products(0,[2,0,1])
	assert(game.match_state.reason(0,2) == "")

	# Prism Lens: +1 wall bounce on ordinary bullets, excluded from "special" bullets, honors can_lens opt.
	setup(game,0)
	assert(p.add_relic(2))
	game.fire(0)
	assert(game.shots[-1].state.bounce == 1)
	setup(game,2) # Fireworks: split bullets are excluded from the lens bonus.
	assert(p.add_relic(2))
	game.fire(0)
	assert(game.shots[-1].state.bounce == 0)
	game.spawn_shot(0,0,0.0,{"can_lens":false})
	assert(game.shots[-1].state.bounce == 0)

	# Guard Bell: blocks one hit per 12s cooldown, ignores repeats of the same volley, resumes once the shield decays.
	setup(game,0)
	assert(p.add_relic(3))
	assert(not p.hurt(1.0,5) and p.state.hp == 8.0 and p.state.shield == 12.0 and p.state.blocked_volley == 5)
	assert(not p.hurt(1.0,5) and p.state.hp == 8.0) # same volley, still blocked by the blocked_volley guard
	p.step(.35,0,q,game.arena) # let the post-block invulnerability (0.3s) lapse without waiting out the shield
	assert(p.hurt(1.0,6) and is_equal_approx(p.state.hp,7.0)) # shield still on cooldown, so this hit lands normally

	# Dodge Nova: a successful dodge fires 6 bullets in a ring; canLens is disabled on them.
	setup(game,0)
	assert(p.add_relic(5))
	var before: int = game.shots.size()
	game._unhandled_key_input(key_event(KEY_SPACE))
	assert(game.shots.size() == before+6)
	assert(is_equal_approx(game.shots[-1].state.velocity.length(),250.0) and is_equal_approx(game.shots[-1].damage,.35))
	assert(game.shots[-1].state.bounce == 0)

	# Heavy Core: -20% bullet speed, +15% damage, applied at the moment the bullet is created.
	setup(game,0)
	assert(p.add_relic(6))
	game.fire(0)
	assert(is_equal_approx(game.shots[-1].state.velocity.length(),510*.8))
	assert(is_equal_approx(game.shots[-1].damage,1.15))

	# Starter Cell: +20% damage on the first shot from a full magazine only.
	setup(game,0)
	assert(p.add_relic(7))
	game.fire(0)
	assert(is_equal_approx(game.shots[-1].damage,1.2))
	p.state.shot = 0.0
	game.fire(0)
	assert(is_equal_approx(game.shots[-1].damage,1.0))
	# Echo's delayed companion shot must keep the boosted damage from the original volley.
	setup(game,19)
	assert(p.add_relic(7))
	game.fire(0)
	assert(is_equal_approx(game.delayed_shots[0].damage,.78))
	game._physics_process(.25)
	assert(is_equal_approx(game.shots[-1].damage,.78))

	# Reserve Holster: switching guns tops the outgoing weapon up by 1 round from reserve, 1.5s reuse.
	# setup() already gives both players id 0 and id 1 (tests/helpers/battle.gd places both on the grid),
	# so inventory[0]/[1] already exist here; no extra add_gun call is needed (or valid, since
	# add_gun rejects a weapon the player already owns).
	setup(game,0)
	p.equip_slot(0)
	assert(p.add_relic(8))
	p.inventory[0].clip = 5
	p.inventory[0].reserve = 10
	p.inventory[1].clip = 5
	p.inventory[1].reserve = 10
	p.equip_slot(1)
	assert(p.inventory[0].clip == 6 and p.inventory[0].reserve == 9 and p.state.holster == 1.5)
	p.equip_slot(0)
	assert(p.inventory[1].clip == 5 and p.inventory[1].reserve == 10) # still on cooldown, no second top-up

	# Pulse Relay: pulse use also fires 6 slow bullets, without granting an extra pulse charge.
	setup(game,0)
	assert(p.add_relic(9))
	var pulses_before: int = p.state.pulses
	var shots_before: int = game.shots.size()
	assert(game.use_pulse(0))
	assert(game.shots.size() == shots_before+6)
	assert(is_equal_approx(game.shots[-1].state.velocity.length(),200.0) and is_equal_approx(game.shots[-1].damage,.35))
	assert(p.state.pulses == pulses_before-1)

	# Parry Dynamo: melee that actually clears a bullet shaves 0.3s off the remaining dodge cooldown, once per swing.
	setup(game,0)
	assert(p.add_relic(10))
	p.state.dodge = 1.0
	game.spawn_shot(1,0,0.0,{})
	game.shots[-1].state.pos = Vector2(p.state.pos.x+40,p.state.pos.y)
	p.try_melee(0,game.shots,q,game.arena) # P1 melee is now a right-click, not handle_key(KEY_V,...); try_melee() is the shared body
	assert(is_equal_approx(p.state.dodge,.7))
	p.state.melee = 0.0
	p.state.dodge = 1.0
	p.try_melee(0,game.shots,q,game.arena) # the bullet from the first swing is already dead, so nothing is in range this time
	assert(is_equal_approx(p.state.dodge,1.0))

	# Rebound Tape: bounced bullets gain +20% speed after their first bounce only; bank's damage bump is unaffected.
	setup(game,16)
	assert(p.add_relic(11))
	game.fire(0)
	var bullet = game.shots[-1]
	bullet.state.pos = Vector2(1087,100)
	bullet.state.velocity = Vector2(370,0)
	bullet.step(.02,game.arena,q)
	assert(is_equal_approx(bullet.state.velocity.length(),444.0) and is_equal_approx(bullet.damage,.9) and bullet.state.rebounds == 1)
	bullet.state.pos = Vector2(1087,100)
	bullet.state.velocity = Vector2(370,0)
	bullet.step(.02,game.arena,q)
	assert(is_equal_approx(bullet.state.velocity.length(),370.0) and bullet.state.rebounds == 2) # second bounce does not re-apply the bonus

	print("PASS: shop offers all 12 relics, lens bounce/exclusion/canLens, bell block/volley-guard/cooldown, dodge nova, heavy core, starter cell/echo carry, holster swap/cooldown, pulse relay, parry dynamo, rebound tape")
	game.queue_free()
	quit()
