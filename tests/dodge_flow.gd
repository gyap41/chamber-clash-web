extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var game = load("res://scenes/game/main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	preload("res://tests/helpers/battle.gd").passive_opponents(game)
	preload("res://tests/helpers/battle.gd").start(game)
	var p = game.players[0]
	var idle := {"dx":0.0,"dy":0.0,"angle":0.0,"shoot":false}
	for id in range(8):
		p.set_character(id)
		p.reset(Vector2(350,450))
		p.add_gun(0)
		p.add_gun(4)
		p.equip_slot(0)
		p.state.shot = 0.0
		p.try_dodge()
		p.request_switch(1)
		var unlock := .31 if id == 0 else .26
		p.step(unlock-.02,0,game.players[1],game.arena,false,idle)
		assert(p.state.gun == 0 and not p.can_fire())
		p.request_fire()
		assert(p.step(.021,0,game.players[1],game.arena,false,idle))
		assert(p.state.gun == 1 and p.get_node("Weapon").visible)
		assert((p.state.roll > 0) == (id == 0))
		assert((p.state.inv > 0) == (id != 0))
		var clip: int = p.weapon().clip
		p.consume_shot()
		assert(p.weapon().clip == clip-1)
		assert(not p.step(.001,0,game.players[1],game.arena,false,idle))
		# Wheel-equivalent repeated switches cannot reset firing wait or refill ammo.
		var cooldown: float = p.state.shot
		for n in range(12): p.request_switch((int(p.state.gun)+1)%2)
		assert(p.state.shot >= cooldown and not p.can_fire())
		assert(p.inventory[1].clip == clip-1)
	# A shot fired just before dodging still blocks a queued switch's follow-up.
	p.set_character(1)
	p.state.roll = 0.0
	p.state.dodge = 0.0
	p.state.shot = .8
	p.try_dodge()
	p.request_switch(1-int(p.state.gun))
	p.step(.24,0,game.players[1],game.arena,false,idle)
	p.request_fire()
	assert(not p.step(.021,0,game.players[1],game.arena,false,idle))
	assert(p.state.shot > .5)
	p.step(.2,0,game.players[1],game.arena,false,idle)
	assert(p.buffered_fire == 0)
	# E and actual wheel events advance from the queued selection, including reversal.
	p.state.roll = .26
	p.clear_action_inputs()
	var original: int = p.state.gun
	game.apply_command(0,preload("res://scripts/combat/human_input.gd").key(p,KEY_E))
	assert(p.switch_selection() == 1-original)
	var wheel := InputEventMouseButton.new()
	wheel.pressed = true
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	game._unhandled_input(wheel)
	assert(p.switch_selection() == original and p.state.gun == original)
	p.clear_action_inputs()
	assert(p.buffered_slot == -1)
	print("PASS: all 8 dodge attack windows, visible landing weapon, queued switch/tap, cooldown and ammo preservation, E/wheel reversal")
	game.queue_free()
	quit()
