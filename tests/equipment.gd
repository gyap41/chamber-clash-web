extends SceneTree
const Weapons = preload("res://scripts/catalog/weapon_catalog.gd")
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var game = load("res://scenes/game/main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	var prep = game.preparation
	var p = game.players[0]
	var q = game.players[1]
	assert(game.phase == "prepare")
	var clock: float = game.remaining
	game.fire(0)
	game._physics_process(.5)
	assert(game.shots.is_empty() and game.remaining == clock)
	assert(not prep.select_gun(-1))
	prep.ready_shop()
	assert(game.phase == "prepare")
	preload("res://tests/helpers/battle.gd").start(game)
	assert(p.add_gun(16) and p.add_gun(19) and not p.add_gun(6))
	assert(q.inventory.size() == 2)
	# Independent ammunition, reload cancellation, empty slots and cycling.
	p.equip_slot(0)
	p.state.shot = 0.0
	game.fire(0)
	assert(p.weapon().clip == 11 and q.inventory[0].clip == 12)
	p.start_reload()
	p.equip_slot(1)
	assert(p.state.reload == 0 and p.state.reload_slot == -1)
	game._physics_process(1.2)
	assert(p.inventory[0].clip == 11 and p.weapon().clip == 12)
	p.equip_slot(0)
	p.weapon().clip = 2
	p.weapon().reserve = 3
	p.start_reload()
	game._physics_process(1.2)
	assert(p.weapon().clip == 5 and p.weapon().reserve == 0)
	p.equip_slot(99)
	assert(p.state.gun == 0)
	for i in range(4): p.handle_key(KEY_E,0,game.shots,q,game.arena)
	assert(p.state.gun == 0)
	game.new_match(17)
	assert(game.scores == [0,0] and game.match_state.builds[0].owned.is_empty())
	assert(p.inventory.size() == 1 and p.weapon().clip == 12 and game.delayed_shots.is_empty())
	combat(game)
	game.new_match(18)
	preload("res://tests/helpers/battle.gd").start(game)
	game.hud.slots[0][0].pressed.emit()
	game.hud.slots[1][0].pressed.emit()
	assert(p.state.gun == 0 and q.state.gun == 0)
	game.hud.slots[1][1].pressed.emit()
	assert(p.state.gun == 0 and q.state.gun == 1)
	print("PASS: preparation gate, independent ammunition, four slots, reload, reset, HUD bindings")
	game.queue_free()
	quit()

func setup(game, id: int) -> void:
	game.reset_round()
	preload("res://tests/helpers/battle.gd").start(game)
	var p = game.players[0]
	if id == 0: p.equip_slot(0)
	elif id != 1: assert(p.add_gun(id))
	p.state.shot = 0.0
	p.state.pos = Vector2(170,100)
	p.state.angle = 0.0
	game.players[1].state.pos = Vector2(950,500)

func combat(game) -> void:
	for id in Weapons.SUPPORTED:
		setup(game,id)
		var p = game.players[0]
		var g := Weapons.definition(id)
		game.fire(0)
		assert(game.shots.size() == int(g.get("count",1)))
		assert(p.weapon().clip == g.mag-1 and is_equal_approx(p.state.shot,g.rate))
		assert(is_equal_approx(game.shots[0].state.velocity.length(),g.speed))
		assert(is_equal_approx(game.shots[0].damage,g.damage))
		game.fire(0)
		assert(p.weapon().clip == g.mag-1)
	setup(game,6)
	game.fire(0)
	var bullet = game.shots[0]
	bullet.state.pos = Vector2(210,190)
	bullet.state.velocity = Vector2(950,0)
	bullet.step(.2,game.arena,game.players[1])
	assert(bullet.state.life <= 0 and bullet.state.pos.x < 240)
	setup(game,16)
	game.fire(0)
	bullet = game.shots[0]
	for i in range(2):
		bullet.state.pos = Vector2(1087,100)
		bullet.state.velocity = Vector2(370,0)
		bullet.step(.02,game.arena,game.players[1])
	assert(is_equal_approx(bullet.damage,1.15) and bullet.state.bounce == 0)
	setup(game,18)
	var p = game.players[0]
	p.weapon().clip = 2
	p.start_reload()
	p.equip_slot(0)
	assert(p.inventory[2].mode == 0)
	p.equip_slot(2)
	p.start_reload()
	game._physics_process(1.2)
	assert(p.weapon().mode == 1 and p.weapon().clip == 6)
	game.fire(0)
	assert(game.shots.size() == 3 and game.shots[0].damage == .5 and p.weapon().clip == 5)
	# All pellets from one volley can damage; another volley is blocked by invulnerability.
	var q = game.players[1]
	q.hurt(.5,100)
	q.hurt(.5,100)
	q.hurt(2,101)
	assert(q.state.hp == 7.0)
	setup(game,19)
	game.fire(0)
	assert(game.delayed_shots.size() == 1)
	game.paused = true
	game._physics_process(.3)
	assert(game.delayed_shots[0].delay == .24)
	game.paused = false
	game.players[0].equip_slot(0)
	game._physics_process(.23)
	assert(game.shots.size() == 1)
	game._physics_process(.02)
	assert(game.shots.size() == 2 and game.shots[1].damage == .65)
	assert(game.shots[0].state.volley == game.shots[1].state.volley)
	setup(game,17)
	game.players[0].weapon().clip = 1
	game.fire(0)
	assert(game.shots[0].state.parcel and game.shots[0].radius == 9)
	game.shots[0].state.life = 0.0
	game._physics_process(.01)
	assert(game.shots.size() == 5 and game.shots[0].damage == .35)
	setup(game,17)
	game.players[0].weapon().clip = 1
	game.fire(0)
	game.shots[0].state.dead = true # melee removal must not explode
	game._physics_process(.01)
	assert(game.shots.is_empty())
	print("PASS: 20 weapon profiles, rail wall collision, bank damage, switch reload, volley damage, echo pause/switch, parcel burst/removal")
