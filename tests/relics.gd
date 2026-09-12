extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func shop(game) -> void:
	game.new_match(71)
	preload("res://tests/helpers/battle.gd").start(game)
func press(code: int, down: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = down
	Input.parse_input_event(event)
	Input.flush_buffered_events()
func run() -> void:
	var game = load("res://scenes/game/main.tscn").instantiate()
	root.add_child(game)
	preload("res://tests/helpers/battle.gd").passive_opponents(game)
	game.set_physics_process(false)
	var p = game.players[0]
	var q = game.players[1]
	var prep = game.preparation
	shop(game)
	assert(p.add_relic(4) and p.add_relic(1))
	assert(p.state.max_hp == 9 and p.state.hp == 9)
	game.supplies.reset()
	p.state.pos = Vector2(100,100)
	q.state.pos = Vector2(950,500)
	var item = game.supplies.put_item("relic",0,p.state.pos)
	assert(not game.supplies.acquire(0,item))
	item.age = .6
	assert(not game.supplies.acquire(0,item))
	assert(game.supplies.acquire(0,item,true) and p.relics.size() == 3)
	assert(not p.add_relic(0) and not p.add_relic(4) and p.state.max_hp == 9)
	# Reject unsupported IDs independently of the inventory capacity.
	var invalid: int = game.Relics.SUPPORTED.size()
	assert(not p.add_relic(invalid) and game.supplies.put_item("relic",invalid,Vector2(200,100)) == null)
	game.supplies.step(.01)
	item = game.supplies.put_item("relic",0,p.state.pos)
	item.age = .6
	var reserve: int = p.weapon().reserve
	assert(not game.supplies.acquire(0,item,true) and not item.used and p.weapon().reserve == reserve)
	# Physical movement is increased, dodge speed is not.
	press(KEY_D,true)
	var start: Vector2 = p.state.pos
	p.step(.1,0,q,game.arena,false,game.HumanInput.sample(p,false))
	press(KEY_D,false)
	assert(is_equal_approx(p.state.pos.x-start.x,21.73))
	p.state.roll = .26
	start = p.state.pos
	p.step(.1,0,q,game.arena)
	assert(is_equal_approx(p.state.pos.x-start.x,59.0))
	p.state.roll = 0
	p.weapon().clip = 0
	p.start_reload()
	assert(is_equal_approx(p.state.reload,1.15*.88))
	p.step(1.02,0,q,game.arena)
	assert(p.weapon().clip == p.definition().mag and p.state.reload == 0)
	# Runtime max HP and modifiers reset without changing Inspector defaults.
	shop(game)
	assert(p.relics.is_empty() and p.state.hp == 8 and p.state.max_hp == 8)
	assert(p.move_speed == 205 and p.reload_duration == 1.15)
	p.state.hp = 3
	assert(p.add_relic(4) and p.state.hp == 4 and p.state.max_hp == 9)
	assert(p.add_relic(4) and p.state.hp == 5 and p.state.max_hp == 10)
	# Acquiring gear during an existing reload affects the next reload only.
	p.weapon().clip = 0
	p.start_reload()
	assert(p.add_relic(1) and p.state.reload == 1.15)
	# Shared three-slot guard, even when additional relic types arrive later.
	p.relics = [0,1,2]
	assert(not p.add_relic(4))
	shop(game)
	p.add_relic(4)
	prep.ready_shop()
	prep.ready_shop()
	# Arena center, safely outside the danger zone even at its maximum extent, so the forced
	# instant round-end below tests only the HP-ratio win/draw logic (see tests/danger_zone.gd
	# for the zone itself).
	p.state.pos = Vector2(560,300)
	q.state.pos = Vector2(560,300)
	game.remaining = .001
	game._physics_process(.01)
	assert(game.result == "DRAW") # full 9/9 vs 8/8
	shop(game)
	p.add_relic(4)
	prep.ready_shop()
	prep.ready_shop()
	p.state.hp = 7
	q.state.hp = 7
	p.state.pos = Vector2(560,300)
	q.state.pos = Vector2(560,300)
	game.remaining = .001
	game._physics_process(.01)
	assert(game.result == "P2 WINS") # 7/9 vs 7/8
	# Field schedule; one shared item for both players, pause/reset.
	shop(game)
	prep.ready_shop()
	prep.ready_shop()
	var s = game.supplies
	assert(s.items.filter(func(x): return x.kind == "relic" and x.gun == 0).is_empty())
	s.reset()
	s.step(34.9)
	assert(s.items.filter(func(x): return x.kind == "relic").is_empty())
	s.step(.11)
	var relic_items = s.items.filter(func(x): return x.kind == "relic")
	assert(relic_items.size() == 1)
	game.paused = true
	var timer: float = s.relic_timer
	s.step(20)
	assert(s.relic_timer == timer)
	game.new_match(71)
	assert(s.relic_timer == 35 and s.items.is_empty())
	print("PASS: relic shop/UI/budget/independence, three slots/duplicate/invalid-id, pickup, physical speed/dodge, reload timing, HP/reset/ratio, field schedule")
	game.queue_free()
	quit()
