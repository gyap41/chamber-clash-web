extends SceneTree
func _initialize() -> void: call_deferred("run")

func prepare(p, q, offset: Vector2) -> void:
	p.reset(Vector2(350,100))
	q.reset(p.state.pos+offset)
	p.state.angle = 0.0

func run() -> void:
	var game = load("res://scenes/game/main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	preload("res://tests/helpers/battle.gd").passive_opponents(game)
	preload("res://tests/helpers/battle.gd").start(game)
	var p = game.players[0]
	var q = game.players[1]
	var events: Array = []
	p.weapon_event_requested.connect(func(e):
		if e.kind == "melee_hit": events.append(e))
	# Circle touches the outer arc, although its centre is beyond the reach.
	for hz in [30,60,120]:
		prepare(p,q,Vector2(p.melee_range+q.radius-.5,0))
		var hp: float = q.state.hp
		var start: Vector2 = q.state.pos
		var count: int = events.size()
		p.try_melee(0,[],q,game.arena)
		assert(q.state.hp < hp and events.size() == count+1)
		assert(events.back().pos.is_equal_approx(p.state.pos+Vector2(p.melee_range,0)))
		for frame in range(ceili(.2*hz)): q.advance_melee_push(1.0/hz,game.arena)
		assert(is_equal_approx(q.state.pos.x-start.x,32.0) and q.melee_push_time == 0)
	# Beyond the outer arc and behind the wielder must miss.
	for offset in [Vector2(p.melee_range+q.radius+1,0),Vector2(-40,0)]:
		prepare(p,q,offset)
		var count: int = events.size()
		var hp: float = q.state.hp
		p.try_melee(0,[],q,game.arena)
		assert(q.state.hp == hp and events.size() == count and q.melee_push_time == 0)
	# Grazing a sector side is a hit; its centre need not be inside the angle.
	prepare(p,q,Vector2.from_angle(p.melee_arc+.1)*50)
	var hp: float = q.state.hp
	p.try_melee(0,[],q,game.arena)
	assert(q.state.hp < hp)
	# Damage rejection must not generate a push or melee-specific flash.
	prepare(p,q,Vector2(40,0))
	q.state.inv = 1.0
	var count: int = events.size()
	p.try_melee(0,[],q,game.arena)
	assert(events.size() == count and q.melee_push_time == 0)
	# Real arena collision: a push stops before the central wall.
	prepare(p,q,Vector2.ZERO)
	p.state.pos = Vector2(450,295)
	q.state.pos = Vector2(494,295)
	p.try_melee(0,[],q,game.arena)
	q.advance_melee_push(.2,game.arena)
	assert(q.state.pos.x <= 501 and not game.arena.solid(q.state.pos,q.radius))
	# A long test swing still cannot reach through that wall.
	p.state.melee = 0.0
	p.melee_range = 180
	q.reset(Vector2(620,295))
	hp = q.state.hp
	count = events.size()
	p.try_melee(0,[],q,game.arena)
	assert(q.state.hp == hp and events.size() == count)
	p.melee_range = 64
	# Transitions/reset discard residual displacement.
	q.melee_push_time = .12
	q.melee_push = Vector2(32,0)
	q.move_to_room(Vector2(400,100))
	q.advance_melee_push(.2,game.arena)
	assert(q.state.pos == Vector2(400,100))
	var visual = game.combat_visuals
	visual.clear()
	for n in range(60): visual.weapon_event({"kind":"melee_hit","pos":Vector2(400,100),"angle":0.0})
	assert(visual.melee_hits.size() == visual.weapon_effect_limit)
	visual.step(.08)
	assert(not visual.melee_hits.is_empty())
	visual.step(.09)
	assert(visual.melee_hits.is_empty())
	print("PASS: melee circle-sector contacts, misses, immunity, wall occlusion, 30/60/120Hz knockback, collision, transition, bounded flash lifecycle")
	game.queue_free()
	quit()
