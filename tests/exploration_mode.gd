extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var title = load("res://scenes/ui/title.tscn").instantiate()
	root.add_child(title)
	title.get_node("Panel/Content/Story").pressed.emit()
	var game = root.get_node("Exploration")
	game.set_physics_process(false)
	assert(game.get("match_state") == null)
	assert(game.exploration.inventory.builds.size() == 1)
	assert(game.exploration.inventory.products == [[]])
	assert(game.exploration.inventory.gold == [0])
	assert(game.players[0].inventory.size() == 1)
	assert(game.players[0].match_inventory != game.players[1].match_inventory)
	var inventory = game.exploration.inventory
	var token = inventory.builds[0].equipped[0]
	assert(not inventory.toggle(0,token))
	assert(not inventory.auto_expand(0))
	assert(not inventory.refresh_shop(0))
	assert(not inventory.confirm(0))
	# Exploration edit authorization does not depend on duel readiness.
	inventory.editing = true
	inventory.ready[0] = true
	assert(inventory.toggle(0,token))
	assert(inventory.place(0,token,inventory.auto_place(0,token)))
	inventory.editing = false
	preload("res://tests/helpers/battle.gd").passive_opponents(game)
	game.set_pause_reason("menu",true)
	game.set_pause_reason("focus",true)
	game.set_pause_reason("menu",false)
	assert(game.paused)
	var pos: Vector2 = game.players[0].state.pos
	game.submit_command("p1",{"dx":1.0})
	game._physics_process(1.0)
	assert(game.players[0].state.pos == pos)
	game.set_pause_reason("focus",false)
	assert(game.submitted_commands.is_empty())
	for tick in range(6000): game._physics_process(1.0/60.0)
	assert(game.result.is_empty() and game.remaining == 0.0 and game.arena_inset() == 0.0)
	assert(game.supplies.items.is_empty())
	game.players[0].state.hp = 0
	game.players[1].state.hp = 0
	game._physics_process(.01)
	assert(game.exploration.status == "dead")
	assert(not inventory.grant_item(0,4))
	assert(not inventory.store_field_weapon(0,1))
	assert(not inventory.toggle(0,token))
	assert(not game.exploration.finish("completed"))
	game.start_exploration(42)
	assert(game.exploration.inventory != inventory)
	assert(game.players[0].state.hp == game.players[0].state.max_hp)
	assert(game.exploration.inventory.gold == [0])
	game.players[1].state.hp = 0
	game._physics_process(.01)
	assert(game.exploration.status == "completed")
	assert(game.exploration.encounter_status == "cleared")
	game.return_to_title()
	var next_title = root.get_children().filter(func(n): return n.get_script() != null and n.get_script().resource_path.ends_with("title.gd") and not n.is_queued_for_deletion())[0]
	next_title.start_cpu_match()
	var select = root.get_children().filter(func(n): return n.get_script() != null and n.get_script().resource_path.ends_with("character_select.gd"))[0]
	select.select_character(0)
	var duel = root.get_node("Game")
	duel.set_physics_process(false)
	assert(duel.match_state.gold == [12,12] and duel.match_state.scores == [0,0])
	assert(duel.combat.countdown_enabled and duel.combat.supplies_enabled)
	duel.preparation.auto_prepare(0)
	duel.preparation.auto_prepare(1)
	duel.launch_round()
	assert(duel.phase == "play")
	assert(not duel.match_state.toggle(0,duel.match_state.builds[0].equipped[0]))
	duel.queue_free()
	await process_frame
	print("PASS: exploration mode isolation, input pause, no countdown, death priority, restart, duel return")
	quit()
