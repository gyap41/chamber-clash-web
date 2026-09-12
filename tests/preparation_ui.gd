extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func motion(at: Vector2, held: bool = false, delta := Vector2.ZERO) -> void:
	var event := InputEventMouseMotion.new()
	event.position = at
	event.global_position = at
	event.relative = delta
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if held else 0
	root.push_input(event,true)
func mouse_button(at: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = at
	event.global_position = at
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	root.push_input(event,true)
func click_at(at: Vector2) -> void:
	motion(at)
	mouse_button(at,true)
	mouse_button(at,false)
func run() -> void:
	var game = load("res://scenes/game/main.tscn").instantiate()
	root.add_child(game)
	preload("res://tests/helpers/battle.gd").passive_opponents(game)
	game.set_physics_process(false)
	game.new_match(1)
	var prep = game.preparation
	var state = game.match_state
	state._set_products(0,[18,19])
	prep.refresh()
	var cards = prep.get_node("Root/Panel/Content/Cards")
	assert(cards.get_child_count() == 3)
	for name in ["Rewards","Equipment","Reserve","Equipment/Details"]:
		assert(cards.get_node(name).is_visible_in_tree())
	var ready = prep.get_node("Root/Panel/Content/Ready")
	assert(not ready.disabled)
	# Claim through the real reward button; acquisition remains storage-only.
	var rewards = cards.get_node("Rewards/Scroll/List")
	var entry = state.rewards[0][0]
	rewards.get_children().filter(func(n): return n is PanelContainer)[0].get_child(0).mouse_entered.emit()
	assert(cards.get_node("Equipment/Details/Name").text == prep.reward_info(entry).name)
	rewards.get_children().filter(func(n): return n is PanelContainer)[0].get_child(0).get_node("Claim").pressed.emit()
	assert(state.relic_id(state.builds[0].owned.back()) == entry and state.builds[0].equipped.is_empty())
	assert(state.gold[0] == 10 and not ready.disabled)
	state.stage = 4
	var gun: String = state.gun_token(1)
	state.builds[0] = {"owned":[gun,18,1,4],"equipped":[],"positions":{},"mods":{}}
	preload("res://tests/helpers/preparation.gd").rectangle(state)
	prep.refresh()
	# Drops on the displayed cells use the same layout validation as the match model.
	var grid = cards.get_node("Equipment/Grid")
	assert(grid.get_child_count() == 36)
	var cell = grid.get_child(0)
	assert(cell._can_drop_data(Vector2.ZERO,{"entry":gun}))
	cell._drop_data(Vector2.ZERO,{"entry":gun})
	assert(gun in state.builds[0].equipped)
	grid = cards.get_node("Equipment/Grid")
	var chip = grid.get_child(0).get_child(0)
	chip.pressed.emit()
	assert(cards.get_node("Equipment/Details/Name").text == prep.entry_info(gun).name)
	# Occupied anchors still receive drag events through their child chip.
	assert(chip._can_drop_data(Vector2.ZERO,{"entry":gun}))
	assert(not chip._can_drop_data(Vector2.ZERO,{"entry":4}))
	# A locked click selection must not change when passing over another item.
	prep.show_detail(0)
	assert(prep.same_entry(prep.placement_entry,gun))
	assert(cards.get_node("Equipment/Details/Name").text == prep.entry_info(gun).name)
	prep.cancel_placement()
	prep.select_entry(18)
	assert(not prep.preview_at(18,Vector2i(0,0)))
	assert("重複" in cards.get_node("Equipment/Details/Status").text)
	var original: Dictionary = state.builds[0].positions.duplicate()
	prep.click_cell(Vector2i(0,0))
	assert(state.builds[0].positions == original)
	assert(not prep.preview_at(4,Vector2i(3,3)))
	assert("未開放" in cards.get_node("Equipment/Details/Status").text)
	assert(prep.preview_at(18,Vector2i(3,3)))
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	grid.get_child(21)._gui_input(click)
	assert(state.builds[0].positions[18] == Vector2i(3,3))
	prep.unequip_relic(18)
	# Grabbing a non-anchor cell preserves the item's offset when relocating.
	grid = cards.get_node("Equipment/Grid")
	var body = grid.get_child(1).get_child(0)
	assert(body.grab_offset == Vector2i(1,0))
	var drag := {"entry":gun,"grab_offset":body.grab_offset}
	assert(grid.get_child(7)._can_drop_data(Vector2.ZERO,drag))
	grid.get_child(7)._drop_data(Vector2.ZERO,drag)
	assert(state.builds[0].positions[gun] == Vector2i(0,1))
	var tray = cards.get_node("Reserve/DropZone")
	assert(tray.get_node("Hint").mouse_filter == Control.MOUSE_FILTER_IGNORE)
	tray._drop_data(Vector2.ZERO,{"entry":gun})
	assert(gun not in state.builds[0].equipped)
	var rows = cards.get_node("Reserve/Scroll/List")
	assert(rows.get_child_count() == 4)
	rows.get_child(0).pressed.emit()
	cards.get_node("Equipment/Details/Discard").pressed.emit()
	assert(gun not in state.builds[0].owned)
	# Eight reserve items remain reachable without expanding or moving the footer.
	state.builds[0] = {"owned":[state.gun_token(9),gun,0,1,2,3,4,5],"equipped":[],"positions":{},"mods":{}}
	prep.refresh()
	await process_frame
	await process_frame
	var reserve_scroll = cards.get_node("Reserve/Scroll")
	rows = reserve_scroll.get_node("List")
	assert(rows.get_child_count() == 8 and rows.size.x > reserve_scroll.size.x)
	reserve_scroll.scroll_horizontal = 10000
	await process_frame
	assert(reserve_scroll.get_global_rect().intersects(rows.get_child(7).get_global_rect()))
	reserve_scroll.scroll_horizontal = 120
	prep.refresh()
	await process_frame
	await process_frame
	reserve_scroll = cards.get_node("Reserve/Scroll")
	assert(reserve_scroll.scroll_horizontal == 120)
	# Pane rectangles may not overlap; scroll content may extend only inside its clip.
	var sections: Array = cards.get_children()
	for a in range(sections.size()):
		for b in range(a+1,sections.size()):
			assert(not sections[a].get_global_rect().intersects(sections[b].get_global_rect()))
	var details = cards.get_node("Equipment/Details")
	assert(not details.get_global_rect().intersects(cards.get_node("Equipment/Grid").get_global_rect()))
	assert(not reserve_scroll.get_global_rect().intersects(cards.get_node("Reserve/DropZone").get_global_rect()))
	for card in cards.get_node("Rewards/Scroll/List").get_children():
		if not card is PanelContainer: continue
		for control in card.get_child(0).get_children():
			assert(card.get_global_rect().encloses(control.get_global_rect()))
	for control in details.get_children():
		assert(details.get_global_rect().encloses(control.get_global_rect()))
	# Complete preparation with no weapon: keep the existing valid unarmed choice.
	prep.refresh()
	assert(not ready.disabled and "近接" in prep.get_node("Root/Panel/Content/Summary").text)
	prep.ready_shop()
	assert(game.phase == "prepare" and prep.turn == 0) # No local hand-off; remote readiness remains separate.
	# Layout fits the 1120x800 logical viewport, including a maximum-size grid.
	await process_frame
	await process_frame
	var content = prep.get_node("Root/Panel/Content")
	assert(cards.get_node("Reserve/Scroll").scroll_horizontal == 0)
	var panel_rect: Rect2 = content.get_global_rect()
	for section in cards.get_children():
		assert(panel_rect.encloses(section.get_global_rect()))
	assert(panel_rect.encloses(ready.get_global_rect()))
	grid = cards.get_node("Equipment/Grid")
	assert(grid.get_child(0).size.x == 58)
	assert(cards.get_node("Equipment").get_global_rect().encloses(grid.get_global_rect()))
	assert(prep.get_node("Root/Shade").color.a == 1.0)
	# Exercise Godot's GUI hit testing and drag threshold, not only callback methods.
	prep.turn = 1 # Explicit participant view for this fixture; no local hand-off exists.
	var sidearm: String = state.gun_token(0)
	state.stage = 1
	state.builds[1] = {"owned":[sidearm,0,4],"equipped":[],"positions":{},"mods":{}}
	prep.cancel_placement()
	prep.reserve_scroll = 0
	prep.refresh()
	await process_frame
	await process_frame
	rows = cards.get_node("Reserve/Scroll/List")
	click_at(rows.get_child(0).get_global_rect().get_center())
	assert(prep.same_entry(prep.placement_entry,sidearm))
	grid = cards.get_node("Equipment/Grid")
	click_at(grid.get_child(0).get_global_rect().get_center())
	assert(state.builds[1].positions[sidearm] == Vector2i.ZERO)
	await process_frame
	await process_frame
	rows = cards.get_node("Reserve/Scroll/List")
	var source: Vector2 = rows.get_child(1).get_global_rect().get_center()
	motion(source)
	mouse_button(source,true)
	motion(source+Vector2(20,-20),true,Vector2(20,-20))
	await process_frame
	assert(root.gui_is_dragging())
	grid = cards.get_node("Equipment/Grid")
	var target: Vector2 = grid.get_child(2).get_global_rect().get_center()
	motion(target,true,target-source)
	await process_frame
	mouse_button(target,false)
	await process_frame
	assert(state.builds[1].positions[4] == Vector2i(2,0))
	print("PASS: full-screen preparation, reward/detail/claim, grid and occupied-cell drops, reserve/discard, unarmed ready, turn reset and layout bounds")
	game.queue_free()
	quit()
