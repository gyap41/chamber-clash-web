extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var game = load("res://scenes/game/main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	var fx = game.combat_visuals
	var p = game.players[0]
	var camera = game.arena.get_node("CombatCamera")
	game.phase = "play"
	assert(p.hurt(1))
	assert(fx.shake_strength == 4.0)
	var pos: Vector2 = p.state.pos
	game._physics_process(.01)
	assert(is_equal_approx(fx.shake_strength,3.7))
	assert(camera.offset == -fx.shake_offset and camera.offset.abs().x <= 3.7 and camera.offset.abs().y <= 3.7)
	assert(p.state.pos == pos and game.arena.position == Vector2.ZERO)
	game.paused = true
	var offset: Vector2 = camera.offset
	game._physics_process(.1)
	assert(camera.offset == offset and is_equal_approx(fx.shake_strength,3.7))
	game.paused = false
	game._physics_process(.2)
	assert(camera.offset == Vector2.ZERO)
	fx.clear()
	p.state.inv = 0.0
	p.add_relic(3)
	assert(not p.hurt(1))
	assert(fx.rings.size() == 1 and fx.rings[0].expansion == 65.0)
	assert(fx.rings[0].color == Color("ffe2a0") and fx.shake_strength == 0.0)
	assert(not p.hurt(1) and fx.rings.size() == 1)
	# All natural explosion types, with gameplay reset between them.
	for pair in [[17,55.0],[2,45.0],[14,45.0],[9,95.0],[10,100.0]]:
		game.reset_round()
		game.phase = "play"
		game.spawn_shot(0,pair[0],0,{"pos":Vector2(400,400),"life":.001,"parcel":pair[0] == 17})
		game._physics_process(.01)
		assert(fx.rings.size() == 1 and fx.rings[0].expansion == pair[1])
		if pair[0] == 9: assert(fx.shake_strength == 5.0)
		game.result = "DRAW"
		game.phase = "result"
		game._physics_process(.1)
		assert(fx.rings[0].age == 0.0)
		fx.step(.46)
		assert(fx.rings.is_empty())
	game.reset_round()
	game.phase = "play"
	game.spawn_shot(0,17,0,{"parcel":true})
	game.shots.back().state.dead = true
	game._physics_process(.01)
	assert(fx.rings.is_empty())
	game.spawn_shot(1,10,0)
	assert(game.use_pulse(0) and fx.shake_strength == 5.0)
	game._physics_process(.01)
	assert(fx.rings.is_empty()) # Explicit pulse removal never explodes.
	for id in [8,9]:
		game.reset_round()
		game.phase = "play"
		p.add_gun(id)
		p.state.shot = 0.0
		game.fire(0)
		assert(fx.shake_strength == 3.0)
	# Successful and rejected pickup attempts; verify every color source.
	for kind in ["ammo","weapon","relic"]:
		game.reset_round()
		preload("res://tests/helpers/battle.gd").start(game,0)
		p.weapon().reserve = 0
		var item = game.supplies.put_item(kind,4,p.state.pos)
		assert(not game.supplies.acquire(0,item) and fx.particles.is_empty())
		item.age = .6
		assert(game.supplies.acquire(0,item,kind != "ammo") and fx.particles.size() == 22)
		var color := Color("a5e9ee") if kind == "ammo" else (Color("a7c5df") if kind == "weapon" else Color(p.Relics.definition(4).color))
		assert(fx.particles[0].color == color)
		assert(not game.supplies.acquire(0,item) and fx.particles.size() == 22)
	game.reset_round()
	game.phase = "play"
	var full = game.supplies.put_item("ammo",0,p.state.pos)
	full.age = .6
	assert(not p.has_weapon())
	assert(not game.supplies.acquire(0,full) and fx.particles.is_empty())
	assert(p.add_gun(0))
	assert(not game.supplies.acquire(0,full) and fx.particles.is_empty())
	fx.shake_scale = 0.0
	fx.shake(5.0)
	assert(fx.shake_offset == Vector2.ZERO)
	game.reset_round()
	assert(fx.rings.is_empty() and fx.shake_strength == 0 and camera.offset == Vector2.ZERO)
	print("PASS: shake triggers/decay/camera-only/pause/reset/disable, shield/explosion rings/lifetime/removal, pickup success/rejection/colors")
	game.queue_free()
	quit()
