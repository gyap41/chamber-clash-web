extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var game = load("res://scenes/game/main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	var p = game.players[0]
	var q = game.players[1]
	var visual = game.arena.get_node("DangerZone")
	assert(not visual.visible)

	# No shrink before 60s elapsed (round_duration defaults to 90, so remaining=40 is elapsed 50s).
	game.remaining = 40.0
	assert(is_equal_approx(game.arena_inset(),0.0))

	# Linear growth from 60s at 7px/sec, capped at 195px.
	game.remaining = 25.0 # elapsed = 65s -> (65-60)*7 = 35
	assert(is_equal_approx(game.arena_inset(),35.0))
	game.remaining = -50.0 # elapsed = 140s, far past the point the 195 cap is reached
	assert(is_equal_approx(game.arena_inset(),195.0))

	# Damage tick: flat 0.16 per physics frame while inside the shrunk margin; the center
	# of the arena stays untouched even once the zone has shrunk.
	game.reset_round()
	preload("res://tests/helpers/battle.gd").start(game,1)
	game.remaining = 25.0 # inset = 35
	p.state.pos = Vector2(10,10) # top-left corner, inside the danger margin
	q.state.pos = Vector2(560,300) # arena center, outside even this margin
	var p_hp: float = p.state.hp
	var q_hp: float = q.state.hp
	game._physics_process(1.0/60.0)
	assert(is_equal_approx(p.state.hp,p_hp-.16))
	assert(is_equal_approx(q.state.hp,q_hp))
	assert(visual.visible and is_equal_approx(visual.inset,game.arena_inset()))
	var rect: Rect2 = visual.safe_rect()
	assert(is_equal_approx(rect.position.x,game.arena_inset()+25.0))
	assert(is_equal_approx(rect.position.y,game.arena_inset()*.58+25.0))
	assert(rect.get_center().is_equal_approx(Vector2(560,300)))
	assert(rect.has_point(q.state.pos) and not rect.has_point(p.state.pos))
	game.paused = true
	var frozen: float = visual.inset
	game._physics_process(1.0)
	assert(is_equal_approx(visual.inset,frozen))
	game.paused = false

	# Hazard damage bypasses Guard Bell, unlike ordinary combat damage (tests/relics2.gd
	# already covers Guard Bell blocking a normal hit).
	assert(p.add_relic(3))
	var before: float = p.state.hp
	p.state.inv = 0.0 # clear the invulnerability the previous hit just granted
	game._physics_process(1.0/60.0)
	assert(is_equal_approx(p.state.hp,before-.16) and p.state.shield == 0.0)

	print("PASS: arena_inset growth/cap, per-tick hazard damage inside/outside the margin, Guard Bell bypass")
	game.result = "DRAW"
	game.phase = "result"
	game._physics_process(1.0)
	assert(visual.visible)
	game.reset_round()
	assert(not visual.visible and visual.inset == 0.0)
	print("PASS: danger boundary matches damage margin, pause/result retain overlay, reset hides it")
	game.queue_free()
	quit()
