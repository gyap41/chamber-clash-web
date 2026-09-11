extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func setup(game, id: int) -> void:
	game.new_match(52)
	preload("res://tests/helpers/battle.gd").start(game,id)
	game.supplies.reset()
	game.players[0].state.pos = Vector2(170,100)
	game.players[0].state.angle = 0.0
	game.players[1].state.pos = Vector2(700,100)
func run() -> void:
	var game = load("res://scenes/game/main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	setup(game,11)
	var p = game.players[0]
	var q = game.players[1]
	game.fire(0)
	var mine = game.shots[0]
	mine.state.age = .6
	mine.state.pos = Vector2(400,100)
	q.state.pos = Vector2(510,100)
	mine.step(.01,game.arena,q)
	assert(not mine.state.launched and mine.state.velocity == Vector2.ZERO)
	q.state.pos = Vector2(480,100)
	mine.step(.01,game.arena,q)
	assert(mine.state.launched and is_equal_approx(mine.state.velocity.length(),440))
	for n in range(30): mine.step(.01,game.arena,q)
	assert(is_equal_approx(q.state.hp,6.4) and mine.state.life <= 0)
	# No sensing through cover, and a triggered mine still can be removed by melee.
	setup(game,11)
	game.fire(0)
	mine = game.shots[0]
	mine.state.age = .6
	mine.state.pos = Vector2(480,295)
	q.state.pos = Vector2(630,295)
	assert(game.arena.line_blocked(mine.state.pos,q.state.pos))
	q.state.pos = Vector2(540,295)
	mine.step(.01,game.arena,q)
	assert(not mine.state.launched)
	mine.state.pos = Vector2(400,100)
	q.state.pos = Vector2(440,100)
	mine.step(.01,game.arena,q)
	q.state.angle = PI
	q.try_melee(1,game.shots,p,game.arena)
	assert(mine.state.dead and mine.fragments().is_empty())
	setup(game,15)
	game.fire(0)
	assert(game.shots.size() == 8 and p.weapon().clip == 3)
	var star = game.shots[0]
	q.state.pos = star.state.pos+Vector2(200,60)
	star.step(.1,game.arena,q)
	assert(star.state.velocity.angle() > .1 and is_equal_approx(star.damage,.8))
	var back_star = game.shots[4]
	var back_angle: float = back_star.state.velocity.angle()
	back_star.step(.01,game.arena,q)
	assert(is_equal_approx(back_star.state.velocity.angle(),back_angle))
	star.state.pos = Vector2(1087,100)
	star.state.velocity = Vector2(340,0)
	star.step(.02,game.arena,q)
	assert(star.state.rebounds == 1 and star.state.life > 0)
	assert(game.use_pulse(1) and game.shots.is_empty())
	# Stronger gravity leaves an escape: roll ignores pull and pulse removes the field.
	setup(game,10)
	game.fire(0)
	assert(p.weapon().clip == 2 and game.shots[0].damage == 1.0)
	var well = game.spawn_well(Vector2(500,100),0)
	q.state.pos = Vector2(630,100)
	well.step(.1,game.arena,game.players,game.shots)
	assert(is_equal_approx(q.state.pos.x,617.5))
	q.state.pos = Vector2(565,100)
	well.state.tick = 0.0
	well.step(.01,game.arena,game.players,game.shots)
	assert(is_equal_approx(q.state.hp,7.35))
	q.handle_key(KEY_SHIFT,1,game.shots,p,game.arena)
	var pos: Vector2 = q.state.pos
	well.state.tick = 0.0
	well.step(.01,game.arena,game.players,game.shots)
	assert(q.state.pos == pos and is_equal_approx(q.state.hp,7.35))
	assert(game.use_pulse(1) and game.wells.is_empty())
	# Count a whole round with pickups cleared after each tick (maximum available drops).
	setup(game,1)
	var counts := {"weapon":0,"relic":0,"ammo":0,"legendary":0}
	var s = game.supplies
	s.launch()
	for second in range(91):
		for item in s.items:
			counts[item.kind] += 1
			if item.kind == "weapon" and game.Weapons.definition(item.gun).rarity == "S": counts.legendary += 1
			item.get_parent().remove_child(item)
			item.queue_free()
		s.items.clear()
		if second < 90: s.step(1.0)
	assert(counts.weapon == 6 and counts.legendary == 2 and counts.relic == 2 and counts.ammo == 14)
	# All equipped relics get an individual name, effect and functioning hover target.
	# P8x：カードのプールはMAX_RELIC_CAPACITY（16）分確保されているが、表示はrelic_capacity分
	# だけに絞られる（残りは非表示）。
	p.relic_capacity = 6
	p.relics = [3,6,12,13,14,16]
	p.temporary_relic = 16
	p.temporary_relic_slot = p.relics.find(16)
	game.hud.refresh_relics(0,p)
	assert(game.hud.relic_cards[0].size() == game.hud.MAX_RELIC_CAPACITY)
	for slot in range(game.hud.MAX_RELIC_CAPACITY): assert(game.hud.relic_cards[0][slot].visible == (slot < 6))
	for n in range(6):
		var card = game.hud.relic_cards[0][n]
		assert(card.mouse_filter == Control.MOUSE_FILTER_STOP)
		assert(card.get_child(0).get_child(0).text.contains(game.Relics.definition(p.relics[n]).name))
		assert(not card.get_child(0).get_child(1).text.is_empty())
		assert(card.tooltip_text.contains(game.Relics.definition(p.relics[n]).desc))
	assert(game.hud.relic_cards[0][5].tooltip_text.contains("仮装備"))
	p.relics = [0]
	game.hud.refresh_relics(0,p)
	assert(game.hud.relic_cards[0][1].get_child(0).get_child(0).text == "空き枠")
	print("PASS: proximity mine, directional star homing/bounce, stronger gravity/counterplay, 90s supply budget (6 weapons/2 relics/14 ammo), individual relic cards")
	game.queue_free()
	quit()
