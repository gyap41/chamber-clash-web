extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func click(at: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = at
	root.push_input(motion,true)
	for down in [true,false]:
		var event := InputEventMouseButton.new()
		event.position = at
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		root.push_input(event,true)
func next_round(game, winner: int) -> void:
	var m = game.match_state
	assert(m.confirm(0) and m.confirm(1))
	game.launch_round()
	m.finish(winner,game.players)
	game.result = "P%d WIN" % (winner+1)
	game.reset_round()
	assert(game.phase == "prepare" and not m.expansion_bought[0])
func run() -> void:
	var game = load("res://scenes/game/main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	var m = game.match_state
	var prep = game.preparation
	# Two paid six-cell patches across real preparation transitions reach 20 cells.
	assert(m.place_expansion(0,"rectangle",Vector2i(0,2)))
	next_round(game,0)
	assert(m.stage == 2 and m.expansion_offer_reason(0,"rectangle").is_empty())
	assert(m.place_expansion(0,"rectangle",Vector2i(0,4)))
	next_round(game,1)
	assert(m.stage == 3 and m.capacity() == 20)
	await process_frame
	await process_frame
	var list = prep.get_node("Root/Panel/Content/Cards/Rewards/Scroll/List")
	assert(list.get_node("Expansion_rectangle").disabled and "残り4" in list.get_node("Expansion_rectangle").text)
	assert(not list.get_node("Expansion_square").disabled)
	var money: int = m.gold[0]
	click(list.get_node("Expansion_square").get_global_rect().get_center())
	assert(prep.selected_expansion == "square" and m.gold[0] == money)
	prep.cancel_placement()
	assert(m.gold[0] == money and m.capacity() == 20)
	click(list.get_node("Expansion_square").get_global_rect().get_center())
	var grid = prep.get_node("Root/Panel/Content/Cards/Equipment/Grid")
	click(grid.get_child(4).get_global_rect().get_center())
	assert(m.capacity() == 24 and m.gold[0] == money-4)
	await process_frame
	await process_frame
	list = prep.get_node("Root/Panel/Content/Cards/Rewards/Scroll/List")
	assert(list.get_node("Expansion_square").disabled and "購入済み" in list.get_node("Expansion_square").text)
	next_round(game,0)
	assert(m.stage == 4 and "残り0" in m.expansion_offer_reason(0,"square"))
	assert(prep.get_node("Root/Panel/Content/Cards/Rewards/Scroll/List/Expansion_square").disabled)
	# Insufficient funds are visible before selection; refusal/cancellation never charge.
	game.new_match(18)
	m = game.match_state
	m.gold[0] = 3
	prep.refresh()
	var before: Array = m.builds.duplicate(true)
	assert(prep.get_node("Root/Panel/Content/Cards/Rewards/Scroll/List/Expansion_square").disabled)
	prep.select_expansion("square")
	assert("資金不足" in prep.detail_path().get_node("Status").text)
	assert(prep.selected_expansion.is_empty() and m.gold[0] == 3 and m.builds == before)
	# A shape with no legal placement reports that geometry constraint before buying.
	m.gold[0] = 12
	assert(m.place_expansion(0,"square",Vector2i(0,2)))
	next_round(game,0)
	assert(m.place_expansion(0,"square",Vector2i(2,3)))
	next_round(game,1)
	assert(m.capacity() == 16 and m.gold[0] >= 6)
	assert(m.expansion_offer_reason(0,"rectangle") == "この形を置ける場所なし")
	assert(m.expansion_offer_reason(0,"square").is_empty())
	game.queue_free()
	await process_frame
	print("PASS: later-round expansion purchase, 20/24 limit UI, once-per-preparation reset, insufficient funds and no-fit feedback, no charge on selection/cancel")
	quit()
