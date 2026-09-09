extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var game = load("res://scenes/game/main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	var m = game.match_state
	m.stage = 4
	m.builds[0] = {"owned":[0,1,2,3,4,5,6,7],"equipped":[0,1,2,3,4,5],"main":1}
	m.rewards[0] = [8,9,10]
	m.remaining[0] = 1
	assert(not m.claim(0,8) and not m.toggle(0,6))
	assert(m.toggle(0,5) and m.toggle(0,6))
	assert(m.builds[0].equipped.size() == 6)
	assert(m.discard(0,7) and m.claim(0,8))
	assert(m.builds[0].owned.size() == 8 and not m.claim(0,9))
	var p = game.players[0]
	p.state.hp = 3
	for n in range(8):
		p.apply_build(m.builds[0],6)
		m.toggle(0,4)
		p.apply_build(m.builds[0],6)
		m.toggle(0,4)
	assert(p.state.hp == 3)
	p.apply_build(m.builds[0],6,true)
	assert(p.state.hp == 10)
	assert(not p.acquire_temporary(9)) # full equipped capacity
	m.toggle(0,3)
	p.apply_build(m.builds[0],6,true)
	assert(p.acquire_temporary(9) and not p.acquire_temporary(10))
	assert(p.temporary_relic == 9 and p.relics.size() == 6)
	# Stored (unequipped) IDs cannot be acquired again on the field.
	p.temporary_relic = -1
	assert(not p.acquire_temporary(3))
	game.new_match(5)
	for i in range(2): game.preparation.auto_prepare(i)
	game.launch_round()
	p.add_gun(8)
	p.weapon().clip = 0
	p.weapon().mode = 1
	p.state.hp = 1
	p.state.pulses = 0
	p.state.shield = 10
	game.players[1].state.hp = 0
	game._physics_process(.01)
	game.reset_round()
	assert(game.match_state.set_main(0,8))
	for i in range(2):
		for id in game.match_state.rewards[i]:
			if game.match_state.remaining[i] > 0: game.match_state.claim(i,id)
		assert(game.match_state.confirm(i))
	game.launch_round()
	assert(p.weapon().id == 8 and p.weapon().clip == p.definition().mag and p.weapon().mode == 0)
	assert(p.state.hp == p.state.max_hp and p.state.pulses == p.initial_pulses and p.state.shield == 0)
	assert(p.inventory.size() == 2)
	print("PASS: 8 inventory, 6 equipment, swap/discard, duplicate/temp guards, no healing exploit, S main/reset")
	game.queue_free()
	quit()
