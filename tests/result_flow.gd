extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func enter(game) -> void:
	var event := InputEventKey.new()
	event.pressed = true
	event.keycode = KEY_ENTER
	game._unhandled_key_input(event)
func finish(game, draw: bool = false) -> void:
	game.remaining = 0.0
	if not draw: game.players[1].state.hp = 0.0
	game._settle_round()
	game.hud.refresh(game.players,game.remaining,false,game.result,game.scores,game.phase)
func capture(name: String) -> void:
	if "--result-screenshot" not in OS.get_cmdline_user_args(): return
	await process_frame
	await process_frame
	root.get_texture().get_image().save_png("res://.local/logs/result-%s.png" % name)
func run() -> void:
	var game = load("res://scenes/game/main.tscn").instantiate()
	root.add_child(game)
	preload("res://tests/helpers/battle.gd").passive_opponents(game)
	game.set_physics_process(false)
	preload("res://tests/helpers/battle.gd").start(game,1)
	var actions = game.hud.get_node("Root/ResultActions")
	finish(game,true)
	assert(actions.get_node("NextRound").visible and "再戦" in actions.get_node("NextRound").text)
	assert(not actions.get_node("Title").visible)
	await capture("draw")
	enter(game)
	assert(game.phase == "play" and game.scores == [0,0])
	finish(game)
	assert(actions.get_node("NextRound").visible and not actions.get_node("CharacterSelect").visible)
	await capture("round")
	game.return_from_result(true)
	assert(game.get_parent() == root) # Guard hidden navigation, too.
	actions.get_node("NextRound").pressed.emit()
	assert(game.phase == "prepare" and game.scores == [1,0] and not actions.visible)
	preload("res://tests/helpers/battle.gd").start(game,1)
	finish(game)
	enter(game)
	assert(game.phase == "prepare" and game.scores == [2,0])
	preload("res://tests/helpers/battle.gd").start(game,1)
	game.scores[0] = 4
	finish(game)
	assert(game.scores[0] == 5 and not actions.get_node("NextRound").visible)
	assert(actions.get_node("CharacterSelect").visible and actions.get_node("Title").visible)
	await capture("match")
	enter(game)
	assert(game.get_parent() == null)
	var select = root.get_child(root.get_child_count()-1)
	assert(select.has_node("Panel/Content/Cards"))
	select.queue_free()
	print("PASS: draw replay, round click/Enter, final-only exits, final Enter selects characters")
	quit()
