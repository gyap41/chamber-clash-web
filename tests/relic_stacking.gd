extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var game = load("res://scenes/game/main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	var m = game.match_state
	m.stage = 4
	var feathers: Array = []
	var chips: Array = []
	for round_index in range(3):
		m.generate_rewards()
		m.rewards[0] = [18,19]
		m.remaining[0] = 2
		assert(game.preparation.claim(18))
		var feather = m.builds[0].owned.back()
		assert(feather not in feathers and m.relic_id(feather) == 18)
		feathers.append(feather)
		assert(not m.claim(0,18) and m.remaining[0] == 1)
		assert(m.place(0,feather,Vector2i(round_index,0)))
		assert(game.preparation.claim(19))
		var chip = m.builds[0].owned.back()
		chips.append(chip)
		assert(m.place(0,chip,Vector2i(round_index,1)))
	var player = game.players[0]
	player.apply_build(m.builds[0],m.capacity(),true)
	assert(is_equal_approx(player.effective_move_speed(),player.move_speed*1.06))
	# Both direct bullets in a volley receive the bonus, derived bullets do not.
	for depth in [0,0,1]:
		var bullet = load("res://scenes/combat/projectile.tscn").instantiate()
		root.add_child(bullet)
		bullet.launch(player,0,0,0.0,{"damage":2.0,"depth":depth})
		assert(is_equal_approx(bullet.damage,2.12 if depth == 0 else 2.0))
		bullet.queue_free()
	game.preparation.cancel_placement()
	game.preparation.refresh()
	game.preparation.show_detail(feathers[0])
	assert("装備中3個 / 同種合計+6%" in game.preparation.detail_description.text)
	assert(m.toggle(0,feathers[1]))
	assert(m.discard(0,chips[1]))
	player.apply_build(m.builds[0],m.capacity(),true)
	assert(is_equal_approx(player.effective_move_speed(),player.move_speed*1.04))
	assert(is_equal_approx(player.Relics.additive_bonus(player.relics,"shot_bonus"),.04))
	# One temporary copy works even when the same type is stored/equipped.
	assert(player.acquire_temporary(18))
	assert(is_equal_approx(player.effective_move_speed(),player.move_speed*1.06))
	assert(not player.acquire_temporary(18))
	player.apply_build(m.builds[0],m.capacity(),true)
	assert(is_equal_approx(player.effective_move_speed(),player.move_speed*1.04))
	# Special relics still cannot be acquired twice, even across reward refreshes.
	m.generate_rewards()
	m.rewards[0] = [3]
	m.remaining[0] = 1
	assert(m.claim(0,3))
	m.generate_rewards()
	m.rewards[0] = [3]
	m.remaining[0] = 1
	assert(not m.claim(0,3))
	game.queue_free()
	await process_frame
	print("PASS: stackable reward instances, additive stats, direct bullets, UI totals, removal and temporary copy")
	quit()
