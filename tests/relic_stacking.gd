extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var game = load("res://scenes/game/main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	var m = game.match_state
	m.stage = 4
	preload("res://tests/helpers/preparation.gd").rectangle(m)
	var feathers: Array = []
	var chips: Array = []
	for round_index in range(3):
		m.generate_rewards()
		m._set_products(0,[18,19])
		assert(game.preparation.claim(18))
		var feather = m.builds[0].owned.back()
		assert(feather not in feathers and m.relic_id(feather) == 18)
		feathers.append(feather)
		assert(not m.claim(0,18) and m.gold[0] == 100-round_index*4-2)
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
	game.hud.refresh_relics(0,player)
	var marked := 0
	for slot in range(player.relics.size()):
		var card = game.hud.relic_cards[0][slot]
		if "【このラウンドの仮装備】" in card.tooltip_text:
			marked += 1
			assert(slot == player.temporary_relic_slot)
		if player.relics[slot] == 18: assert("同種3個 / 合計+6%" in card.tooltip_text)
	assert(marked == 1)
	assert(not player.acquire_temporary(18))
	player.apply_build(m.builds[0],m.capacity(),true)
	assert(is_equal_approx(player.effective_move_speed(),player.move_speed*1.04))
	# Special relics still cannot be acquired twice, even across reward refreshes.
	m.generate_rewards()
	m._set_products(0,[3])
	assert(m.claim(0,3))
	m.generate_rewards()
	m._set_products(0,[3])
	assert(not m.claim(0,3))
	# CPU duplicates and round snapshots preserve each individual item.
	m._set_products(1,[18,19])
	game.preparation.auto_prepare(1)
	var first: Array = m.builds[1].owned.duplicate()
	m.start_round()
	player.apply_build(m.builds[0],m.capacity(),true)
	assert(player.acquire_temporary(19))
	m.finish(0,game.players)
	assert(m.temporary[0] == 19)
	assert(m.previous[1].owned == first)
	m._set_products(1,[18,19])
	game.preparation.auto_prepare(1)
	assert(m.equipped_relics(1).count(18) == 2)
	assert(m.equipped_relics(1).count(19) == 2)
	for entry in first: assert(entry in m.builds[1].owned)
	assert(m.previous[1].owned == first)
	player.apply_build(m.builds[0],m.capacity(),true)
	assert(player.temporary_relic_slot == -1 and player.temporary_relic == -1)
	# Exercise actual expiry blast, derived fragments, and melee with three power chips.
	game.new_match(71)
	preload("res://tests/helpers/battle.gd").start(game,9)
	player.relics = [19,19,19]
	player.state.pos = Vector2(170,100)
	player.state.angle = 0.0
	var enemy = game.players[1]
	enemy.state.pos = Vector2(560,100)
	game.fire(0)
	assert(game.shots.size() == 1)
	var comet = game.shots[0]
	assert(is_equal_approx(comet.damage,float(player.definition().damage)*1.06))
	comet.state.pos = Vector2(500,100)
	comet.state.life = 0
	game._physics_process(.01)
	assert(is_equal_approx(enemy.state.hp,6.5) and game.shots.size() == 12)
	for shard in game.shots: assert(is_equal_approx(shard.damage,.45))
	player.state.angle = 0.0 # Physics updates aim from the mouse; aim the isolated melee explicitly.
	enemy.state.inv = 0.0
	enemy.state.pos = player.state.pos+Vector2(40,0)
	player.try_melee(0,game.shots,enemy,game.arena)
	assert(is_equal_approx(enemy.state.hp,6.5-player.melee_damage))
	game.queue_free()
	await process_frame
	print("PASS: stackable reward instances, additive stats, direct bullets, UI totals, removal and temporary copy")
	quit()
