extends SceneTree
const Relics = preload("res://scripts/catalog/relic_catalog.gd")
const Shop = preload("res://scripts/catalog/shop_catalog.gd")
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var game = load("res://scenes/game/main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	var p = game.players[0]
	var q = game.players[1]
	var ids := [0,1,4,6,7,11,18,19,20,21,22,24,25,26,29,30,31,32,34]
	var prices := [4,4,4,4,3,2,2,2,3,4,3,4,2,3,2,3,3,3,2]
	for id in Relics.SUPPORTED:
		assert(Relics.stackable(id) == (id in ids))
	for index in range(ids.size()):
		var id: int = ids[index]
		assert(Shop.price(id) == prices[index])
		game.new_match(91)
		var m = game.match_state
		preload("res://tests/helpers/preparation.gd").rectangle(m)
		m._set_products(0,[id,id])
		for card in m.products[0]: assert(m.purchase(0,card.id))
		var copies: Array = m.builds[0].owned.filter(func(e): return m.is_relic(e))
		assert(copies.size() == 2 and copies[0] != copies[1])
		assert(m.place(0,copies[0],Vector2i(0,0)))
		assert(m.place(0,copies[1],Vector2i(2,2)))
		p.apply_build(m.builds[0],m.capacity(),true)
		assert(p.relics.count(id) == 2 and p.acquire_temporary(id))
		game.hud.refresh_relics(0,p)
		assert("同種3個" in game.hud.relic_cards[0][0].tooltip_text)
		assert(m.sell(0,copies[0]) and copies[1] in m.builds[0].owned)
	preload("res://tests/helpers/battle.gd").start(game)
	p.relic_capacity = 24
	p.relics = [0,0,0,18,1,1,1,24,24,26,26,34,34]
	assert(is_equal_approx(p.effective_move_speed(),205*1.20))
	assert(is_equal_approx(p.effective_reload_duration(),1.15*pow(.88,3)))
	assert(is_equal_approx(p.effective_chest_duration(1.5),1.5*.81))
	p.handle_key(KEY_SPACE,0,game.shots,q,game.arena)
	assert(is_equal_approx(p.state.dodge,1.65*.94*.94) and p.state.roll == .26)
	p.state.roll = 0
	p.try_melee(0,game.shots,q,game.arena)
	assert(is_equal_approx(p.state.melee,1.1*.92*.92))
	p.relics = [25,25,29,29,30,30]
	p.state.sole_time = .8
	assert(game.use_pulse(0) and p.state.boots_time == 2.0)
	assert(is_equal_approx(p.effective_move_speed(),205*1.28))
	p.equip_slot(0)
	assert(p.state.sight_time == 2.0 and p.state.sight_cd == 2.0)
	assert(is_equal_approx(p.relic_value(30,"sight_bonus"),.24))
	p.relics = [6,6,6,7,7,20,20,22,22,11,11,31,31,32,32]
	p.state.shot = 0
	p.state.sight_time = 0
	p.state.angle = 0
	p.state.pos = Vector2(170,100)
	p.equip_slot(0)
	p.weapon().clip = p.definition().mag
	game.fire(0)
	assert(is_equal_approx(game.shots[-1].damage,.8*1.2*1.24))
	assert(is_equal_approx(game.shots[-1].speed,480*1.16*pow(.9,3)))
	game.spawn_shot(0,0,0,{"depth":1,"damage":1.0,"speed":200.0})
	assert(is_equal_approx(game.shots[-1].damage,1.24))
	assert(is_equal_approx(game.shots[-1].speed,200*pow(.9,3)))
	p.state.shot = 0
	p.weapon().clip = 1
	game.fire(0)
	assert(is_equal_approx(game.shots[-1].damage,(.8+.30)*1.24))
	assert(is_equal_approx(p.relic_value(11,"rebound_bonus"),.20))
	assert(is_equal_approx(p.relic_value(31,"rubber_bonus"),.12))
	assert(is_equal_approx(p.relic_value(32,"fragment_bonus"),.12))
	p.relics = [21,21,21]
	assert(p.definition().mag == 19)
	p.state.hp = 3
	p.state.max_hp = 8
	assert(p.add_relic(4) and p.add_relic(4))
	assert(p.state.max_hp == 10 and p.state.hp == 5)
	assert(Relics.stack_summary(1,3) == "-31.9%")
	assert(Relics.stack_summary(4,3) == "+3HP")
	# Direct fixture edits bypass the normal frame update of cached orbit positions.
	p.sync_visual()
	print("PASS: all 19 duplicate purchase/place/sale/temporary/UI paths, prices, additive stats, diminishing reductions, fixed timers, direct/derived shots and HP increments")
	game.queue_free()
	quit()
