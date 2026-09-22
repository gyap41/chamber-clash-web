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
	assert(game.players.size() == 1 and game.roster.participants.size() == 1)
	assert(game.get_node("Arena/Players").get_child_count() == 1)
	assert(not game.players[0].is_cpu and not game.submit_command("p2",{}))
	assert(game.exploration.encounter_status == "none")
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
	assert(game.players[0].state.hp == game.players[0].state.max_hp)
	assert("敵なし" in game.hud.get_node("Root/Status").text)
	# Movement and firing still run with no nearest enemy; shots have only P1 ownership.
	var start_pos: Vector2 = game.players[0].state.pos
	game.submit_command("p1",{"dx":1.0,"angle":0.0,"shoot":true})
	game._physics_process(.1)
	assert(game.players[0].state.pos.x > start_pos.x)
	assert(not game.shots.is_empty() and game.shots.all(func(shot): return shot.state.owner == 0))
	assert(game.result.is_empty())
	game.players[0].state.hp = 0
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
	game._physics_process(.01)
	assert(game.players.size() == 1 and game.exploration.status == "active")
	assert(game.exploration.encounter_status == "none" and game.result.is_empty())
	# A non-combat room is distinct from an explicitly started encounter.
	var progress = preload("res://scripts/game/exploration_state.gd").new(9)
	progress.settle(true,false)
	assert(progress.status == "active")
	progress.encounter_status = "active"
	progress.settle(true,true)
	assert(progress.status == "active")
	progress.settle(true,false)
	assert(progress.status == "active" and progress.encounter_status == "cleared")
	progress = preload("res://scripts/game/exploration_state.gd").new(9)
	progress.encounter_status = "active"
	progress.settle(false,false)
	assert(progress.status == "dead")
	game.return_to_title()
	var next_title = root.get_children().filter(func(n): return n.get_script() != null and n.get_script().resource_path.ends_with("title.gd") and not n.is_queued_for_deletion())[0]
	next_title.start_cpu_match()
	var select = root.get_children().filter(func(n): return n.get_script() != null and n.get_script().resource_path.ends_with("character_select.gd"))[0]
	select.select_character(0)
	var duel = root.get_node("Game")
	duel.set_physics_process(false)
	assert(duel.match_state.gold == [12,12] and duel.match_state.scores == [0,0])
	assert(duel.combat.countdown_enabled and duel.combat.supplies_enabled)
	assert(duel.players.size() == 2 and duel.players[1].is_cpu)
	duel.preparation.auto_prepare(0)
	duel.preparation.auto_prepare(1)
	duel.launch_round()
	assert(duel.phase == "play")
	assert(not duel.match_state.toggle(0,duel.match_state.builds[0].equipped[0]))
	duel.queue_free()
	await process_frame
	print("PASS: enemy-free exploration, movement/fire, no automatic clear, pause, death priority, restart, duel CPU preserved")
	quit()
