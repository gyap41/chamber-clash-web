extends SceneTree
func _initialize() -> void:
	call_deferred("run")
# Reach "play" phase the same way other tests do (draft -> shop -> launch_round), then clear
# the launch-time pickups so isolated behaviors below aren't accidentally overridden by
# item-seeking (that has its own dedicated test with manually placed items).
func enter_play(game) -> void:
	preload("res://tests/helpers/battle.gd").start(game,1)
	game.supplies.reset()
func run() -> void:
	var game = load("res://scenes/game/main.tscn").instantiate()
	root.add_child(game)
	preload("res://tests/helpers/battle.gd").passive_opponents(game)
	game.set_physics_process(false)
	enter_play(game)
	var p = game.players[1] # CPU always controls player index 1
	var enemy = game.players[0]
	game.remaining = game.round_duration # elapsed = 0, so the strafe/aim-jitter terms are 0

	# Base kiting: chase when far (d>340), retreat when close (d<200), pure strafe in between.
	# Held on the x=170 column, clear of all three walls (which all start at x>=240), so none
	# of these trigger the obstacle-avoidance turn tested separately below.
	p.state.pos = Vector2(170,300)
	enemy.state.pos = Vector2(170,650) # straight south, d=350 > 340
	var chase: Dictionary = game.CpuAI.decide(game,p,enemy,1.0/60.0)
	assert(chase.dy > .9 and absf(chase.dx) < .1) # heads toward the enemy (south)
	enemy.state.pos = Vector2(170,450) # d=150 < 200
	var flee: Dictionary = game.CpuAI.decide(game,p,enemy,1.0/60.0)
	assert(flee.dy < -.9 and absf(flee.dx) < .1) # heads away from the enemy (north)
	enemy.state.pos = Vector2(170,570) # d=270, between 200 and 340: pure strafe, no forward/back
	var hold: Dictionary = game.CpuAI.decide(game,p,enemy,1.0/60.0)
	assert(is_zero_approx(hold.dy) and is_zero_approx(hold.dx))

	# Weapon auto-switch: if the active weapon is completely dry, switch to any weapon with ammo.
	# Pick an id the draft didn't already hand to p: choices[0] (drafted by enter_play()) is a
	# random B-rarity pick, so a fixed candidate id here could collide with it and make add_gun()
	# fail (already-owned), which is what actually happened on a real run.
	var fresh_id := -1
	for candidate in [1,3,6,7,11,12,13,16,17,18,19]:
		if not p.inventory.any(func(x): return x.id == candidate):
			fresh_id = candidate
			break
	assert(fresh_id != -1)
	assert(p.add_gun(fresh_id))
	p.equip_slot(0)
	p.inventory[0].clip = 0
	p.inventory[0].reserve = 0
	assert(p.state.gun == 0)
	game.CpuAI.decide(game,p,enemy,1.0/60.0)
	assert(p.state.gun == 1) # switched to the weapon that still has ammo

	# Shoot decision: blocked line of sight with a non-bouncing weapon withholds fire; a
	# bounce weapon (or boomerang) fires anyway, since it can still reach around a wall.
	# Locate (or acquire) the bounce weapon (id 1, 跳弾キャンディ) by id rather than assuming it
	# sits at inventory slot 1 — the draft/auto-switch above may have placed it anywhere, or the
	# fresh_id pick above may already have added it.
	var bounce_index := -1
	for n in range(p.inventory.size()):
		if p.inventory[n].id == 1:
			bounce_index = n
			break
	if bounce_index < 0:
		assert(p.add_gun(1))
		bounce_index = p.inventory.size()-1
	p.equip_slot(0) # back to the dry P-12 (id 0, no bounce/boomerang)
	p.inventory[0].clip = 5
	p.state.pos = Vector2(560,220) # above Wall3 (515-605 x, 250-340 y)
	enemy.state.pos = Vector2(560,380) # below Wall3: line of sight passes through it
	assert(game.arena.line_blocked(p.state.pos,enemy.state.pos))
	var blocked_decision: Dictionary = game.CpuAI.decide(game,p,enemy,1.0/60.0)
	assert(blocked_decision.shoot == false)
	p.equip_slot(bounce_index) # 跳弾キャンディ: bounce=2, still worth firing even when blocked
	var bounce_decision: Dictionary = game.CpuAI.decide(game,p,enemy,1.0/60.0)
	assert(bounce_decision.shoot == true)
	enemy.state.pos = Vector2(900,220) # clear line of sight, same height, no wall between
	var clear_decision: Dictionary = game.CpuAI.decide(game,p,enemy,1.0/60.0)
	assert(clear_decision.shoot == true)

	# Obstacle avoidance: the naive southward path from directly above Wall3 collides, so the
	# AI should turn to one of the three candidate headings (+90/-90/180) instead.
	p.state.pos = Vector2(560,220)
	enemy.state.pos = Vector2(560,580) # d=360>340, naive direction is due south into Wall3
	assert(game.arena.solid(p.state.pos+Vector2(0,1)*40.0,18.0))
	var avoid: Dictionary = game.CpuAI.decide(game,p,enemy,1.0/60.0)
	assert(not game.arena.solid(p.state.pos+Vector2(avoid.dx,avoid.dy)*45.0,18.0))
	assert(absf(avoid.dy) < .3) # turned away from due-south, not just softened

	# Danger zone: outside the CPU's wider (+65/+60) avoidance margin, movement heads for
	# arena center regardless of where the enemy is.
	game.remaining = game.round_duration-70.0 # elapsed=70 -> inset=min(195,(70-60)*7)=70
	assert(game.arena_inset() == 70.0)
	p.state.pos = Vector2(70,90) # inside fighter_bounds but still inside the inset(70)+65 margin
	enemy.state.pos = Vector2(900,90) # somewhere that would otherwise pull movement east
	var zone: Dictionary = game.CpuAI.decide(game,p,enemy,1.0/60.0)
	var to_center: Vector2 = Vector2(560,300)-p.state.pos
	assert(absf(wrapf(Vector2(zone.dx,zone.dy).angle()-to_center.angle(),-PI,PI)) < .01)
	game.remaining = game.round_duration # back to elapsed=0 for the remaining checks

	# Bullet dodge: a nearby enemy-owned bullet adds perpendicular steering and, once the
	# per-CPU cooldown expires, triggers an actual dodge roll.
	p.state.pos = Vector2(560,490) # same "hold" spot used above, so base dx=dy=0
	enemy.state.pos = Vector2(560,220) # irrelevant to this check beyond distance-band
	game.spawn_shot(0,0,0.0,{"pos":Vector2(560,470),"speed":0.0}) # owner 0, 20px north of p
	assert(p.state.dodge == 0.0)
	p.state.ai_cd = -0.1 # force the cooldown to already be expired
	var dodge: Dictionary = game.CpuAI.decide(game,p,enemy,1.0/60.0)
	assert(not (is_zero_approx(dodge.dx) and is_zero_approx(dodge.dy))) # threat steering applied
	assert(p.state.dodge > 0.0) # the cooldown expiring triggered an actual roll
	assert(p.state.ai_cd >= .35 and p.state.ai_cd <= .75) # cooldown re-armed
	for shot in game.shots.duplicate():
		shot.get_parent().remove_child(shot)
		shot.queue_free()
	game.shots.clear()

	# Pulse auto-use: swarmed by more than 5 of the enemy's bullets within 120px, and pulses
	# still available, triggers use_pulse() for the CPU (index 1).
	p.state.pos = Vector2(170,300)
	p.state.pulses = 2
	for n in range(6):
		game.spawn_shot(0,0,0.0,{"pos":p.state.pos+Vector2(10.0+n,0),"speed":0.0})
	game.CpuAI.decide(game,p,enemy,1.0/60.0)
	assert(p.state.pulses == 1) # one pulse consumed
	for shot in game.shots.duplicate():
		shot.get_parent().remove_child(shot)
		shot.queue_free()
	game.shots.clear()

	# Reload-when-empty and melee-when-close are triggered unconditionally by decide(), not
	# gated behind the shoot decision (matches legacy's aiInput doing both inline).
	p.state.pos = Vector2(170,300)
	p.inventory[p.state.gun].clip = 0
	p.inventory[p.state.gun].reserve = 10
	assert(p.state.reload == 0.0)
	enemy.state.pos = Vector2(170,600) # far enough that melee doesn't also fire this call
	game.CpuAI.decide(game,p,enemy,1.0/60.0)
	assert(p.state.reload > 0.0)
	# Melee-when-close, checked separately: handle_key()'s melee guard requires reload<=0 (the
	# same rule human melee follows), so give the weapon ammo back and clear the reload the
	# previous decide() call just started — otherwise this decide() call would immediately
	# re-trigger reload-when-empty again and self-block the melee check that follows it. Also
	# clear roll: the earlier bullet-dodge sub-test triggered an actual dodge roll (state.roll =
	# dodge_duration) via handle_key(), and nothing decrements it here — these unit tests call
	# CpuAI.decide() directly rather than Player.step(), which is what normally counts timers
	# down each frame — so it would otherwise still read >0 and block the melee guard below.
	p.inventory[p.state.gun].clip = 5
	p.state.reload = 0.0
	p.state.roll = 0.0
	enemy.state.hp = enemy.state.max_hp
	enemy.state.pos = p.state.pos+Vector2(30,0) # within melee_range(64) and dead ahead
	p.state.angle = (enemy.state.pos-p.state.pos).angle() # step() normally locks this each frame
	assert(p.state.melee == 0.0)
	game.CpuAI.decide(game,p,enemy,1.0/60.0)
	assert(p.state.melee > 0.0) # melee cooldown started
	assert(enemy.state.hp < enemy.state.max_hp) # and it actually landed

	# Item seeking: a desired pickup within cost 500 overrides movement, and an S-rarity weapon
	# is weighted as if 35% closer, so it can out-pull a nearer non-S item.
	game.reset_round()
	enter_play(game)
	p = game.players[1]
	enemy = game.players[0]
	game.remaining = game.round_duration
	p.state.pos = Vector2(170,300)
	p.state.pulses = 0 # avoid the panic-pulse branch interfering with this section
	var item_c = game.supplies.put_item("weapon",0,Vector2(170,400)) # C-rarity, cost 100*1=100
	var item_s = game.supplies.put_item("weapon",8,Vector2(300,300)) # S-rarity, cost 130*.65=84.5
	assert(item_c != null and item_s != null)
	var weighted: Dictionary = game.CpuAI.decide(game,p,enemy,1.0/60.0)
	var to_s: Vector2 = item_s.position-p.state.pos
	assert(absf(wrapf(Vector2(weighted.dx,weighted.dy).angle()-to_s.angle(),-PI,PI)) < .01) # farther S item wins over the nearer C one
	game.supplies.reset()

	# Standing next to a desired item acquires it. decide()'s own "close enough to attempt"
	# check is <45px, but supplies.acquire() itself only actually succeeds within its
	# touch_radius (31px), so this stands well inside both.
	p.state.pos = Vector2(170,300)
	var ammo_item = game.supplies.put_item("ammo",0,Vector2(170,480)) # due south, 180px away
	assert(ammo_item != null)
	ammo_item.age = game.supplies.pickup_delay # skip the 0.6s pickup delay acquire() enforces;
	# nothing here ticks item.age itself since these tests call CpuAI.decide() directly and never
	# call the supplies tick that normally runs from main.gd's _physics_process each frame.
	p.inventory[0].reserve = 1 # far below 60% of stock(60), so the ammo box is desired
	var seek: Dictionary = game.CpuAI.decide(game,p,enemy,1.0/60.0)
	var to_item: Vector2 = ammo_item.position-p.state.pos
	assert(absf(wrapf(Vector2(seek.dx,seek.dy).angle()-to_item.angle(),-PI,PI)) < .01)
	p.state.pos = ammo_item.position+Vector2(10,0)
	game.CpuAI.decide(game,p,enemy,1.0/60.0)
	assert(p.inventory[0].reserve > 1) # picked up in the same call that got this close
	game.supplies.reset()
	# Lead a moving target; do not lead a stationary target or aim through a wall.
	p.state.pos = Vector2(170,180)
	enemy.state.pos = Vector2(400,180)
	p.state.erase("ai_enemy_pos")
	var first: Vector2 = game.CpuAI.predicted_target(p.state,enemy,{"speed":500.0},.1,game.arena)
	assert(first == enemy.state.pos)
	enemy.state.pos.y += 15.0
	var lead: Vector2 = game.CpuAI.predicted_target(p.state,enemy,{"speed":500.0},.1,game.arena)
	assert(lead.y > enemy.state.pos.y)
	assert(game.CpuAI.predicted_target(p.state,enemy,{"speed":500.0},.1,game.arena) == enemy.state.pos)
	# Incoming fast bullets are detected before entering the old 90px radius.
	p.state.pos = Vector2(170,300)
	enemy.state.pos = Vector2(170,520)
	p.state.roll = 0.0
	p.state.dodge = 0.0
	p.state.ai_cd = 0.0
	p.state.dir = Vector2.DOWN
	game.spawn_shot(0,0,0.0,{"pos":Vector2(60,300),"speed":500.0})
	var early: Dictionary = game.CpuAI.decide(game,p,enemy,1.0/60.0)
	assert(p.state.roll > 0.0)
	assert(p.state.dir.is_equal_approx(Vector2(early.dx,early.dy).normalized()))
	for shot in game.shots:
		shot.queue_free()
	game.shots.clear()
	# A nearby departing bullet must not consume a roll.
	p.state.roll = 0.0
	p.state.dodge = 0.0
	p.state.ai_cd = 0.0
	game.spawn_shot(0,0,0.0,{"pos":Vector2(210,300),"speed":500.0})
	game.CpuAI.decide(game,p,enemy,1.0/60.0)
	assert(p.state.roll == 0.0)
	for shot in game.shots:
		shot.queue_free()
	game.shots.clear()
	# Unarmed CPU closes into melee instead of retreating at 150px.
	p.inventory.clear()
	enemy.state.pos = Vector2(170,450)
	var unarmed: Dictionary = game.CpuAI.decide(game,p,enemy,1.0/60.0)
	assert(unarmed.dy > .9 and not unarmed.shoot)

	print("PASS: CPU kiting/retreat/hold, weapon auto-switch, shoot decision (blocked/bounce/clear), obstacle avoidance, danger-zone retreat, bullet dodge + roll, panic pulse, reload-when-empty, melee-when-close, pickup seek + acquire")
	game.queue_free()
	quit()
