extends "res://tests/exploration_treasure_supplies.gd"

func run() -> void:
	var game = load("res://scenes/game/exploration.tscn").instantiate()
	game.random_floor = true
	root.add_child(game)
	game.set_physics_process(false)
	game.start_exploration(22)
	game.set_pause_reason("focus",false)
	var player = game.players[0]
	assert(player.state.hp == 4.0 and player.state.max_hp == 4.0)
	player.state.hp = 2.0
	var baseline: float = player.Weapons.definition(20).damage
	assert(player.infinite_reserve(20) and not player.infinite_reserve(4))
	assert(is_equal_approx(player.definition().damage,baseline*.75))
	var w: Dictionary = player.weapon()
	w.reserve = 0
	for i in range(20):
		w.clip = 0
		player.state.reload = 0
		player.start_reload()
		assert(player.state.reload > 0)
		player.finish_reload()
		assert(w.clip == player.definition().mag and w.reserve == 0)
	assert(player.refill_ammo() == 0)
	var view = preload("res://scripts/ui/combat_hud_view.gd").capture(player,true)
	assert(view.weapons[0].infinite_reserve)
	assert(game.Loadout.apply(player,game.exploration.inventory,game.exploration.inventory.builds[0].duplicate(true),game.exploration.weapon_bank))
	assert(player.infinite_reserve(20))
	assert(player.state.hp == 2.0 and player.state.max_hp == 4.0)
	# Default actors retain duel damage and finite reserve behavior.
	player.exploration_starter = false
	assert(is_equal_approx(player.definition().damage,baseline))
	player.weapon().clip = 0
	player.weapon().reserve = 0
	player.state.reload = 0
	player.start_reload()
	assert(player.state.reload == 0)
	player.exploration_starter = true
	var normal: Array = game.floor_data.rooms.keys().filter(func(id): return game.floor_data.rooms[id].role == "normal")
	for i in range(normal.size()):
		enter(game,normal[i])
		for enemy in game.players.slice(1):
			assert(enemy.radius >= 18 and not enemy.infinite_reserve(20))
			assert(not game.arena.solid(enemy.state.pos,enemy.radius))
			var hp: float = enemy.state.hp
			# This point is outside the old 14px body even with the 1px projectile.
			game.spawn_shot(0,20,0,{"pos":enemy.state.pos+Vector2(enemy.radius-.5,0),"radius":1.0,"speed":0.0,"damage":.1,"life":.1})
			game.combat._step_projectiles(.001)
			assert(enemy.state.hp < hp)
			enemy.state.hp = 0
		game._physics_process(.01)
		var items = game.ExplorationSupplies.entries(game)
		assert(items.filter(func(item): return item.kind == "ammo").size() == (1 if (i+1)%2 == 0 else 0))
		assert(items.filter(func(item): return item.kind == "heal").size() == (1 if (i+1)%3 == 0 else 0))
	game.start_exploration(22)
	assert(player.state.hp == 4.0 and player.state.max_hp == 4.0)
	game.queue_free()
	await process_frame
	print("PASS: infinite starter reload, reduced isolated damage, finite duel policy, loadout, larger enemy bodies and six-room supply cadence")
	quit()
