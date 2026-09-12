extends SceneTree
const Characters = preload("res://scripts/catalog/character_catalog.gd")
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
func run() -> void:
	for cpu in [true]:
		for character in range(Characters.count()):
			var select = load("res://scenes/ui/character_select.tscn").instantiate()
			root.add_child(select)
			select.set_mode(cpu)
			select.select_character(character)
			var game = root.get_children().filter(func(n): return n.get_script() != null and n.get_script().resource_path.ends_with("main.gd"))[0]
			game.set_physics_process(false)
			var m = game.match_state
			var prep = game.preparation
			var gun: String = m.gun_token(Characters.start_gun(character))
			await process_frame
			await process_frame
			# No manual refresh: validate the actual first screen after character selection.
			var rows = prep.get_node("Root/Panel/Content/Cards/Reserve/Scroll/List")
			assert(rows.get_child(0).entry == gun and m.builds[0].owned == [gun])
			assert(rows.get_child(0).tooltip_text.begins_with(prep.entry_info(gun).name))
			assert(("対戦開始" in prep.get_node("Root/Panel/Content/Ready").text) == cpu)
			click(rows.get_child(0).get_global_rect().get_center())
			var grid = prep.get_node("Root/Panel/Content/Cards/Equipment/Grid")
			click(grid.get_child(0).get_global_rect().get_center())
			assert(m.builds[0].positions[gun] == Vector2i.ZERO and m.occupied_cells(0).size() == 2)
			prep.unequip_relic(gun)
			await process_frame
			await process_frame
			var before: Dictionary = m.builds[0].acquisitions[gun].duplicate(true)
			var offer: Dictionary = m.products[0].filter(func(card): return typeof(card.entry) == TYPE_INT and m.purchase_reason(0,card.id).is_empty())[0]
			assert(prep.claim(offer.id))
			assert(gun in m.builds[0].owned and m.builds[0].acquisitions[gun] == before)
			await process_frame
			await process_frame
			rows = prep.get_node("Root/Panel/Content/Cards/Reserve/Scroll/List")
			assert(rows.get_child(0).entry == gun)
			click(rows.get_child(0).get_global_rect().get_center())
			grid = prep.get_node("Root/Panel/Content/Cards/Equipment/Grid")
			click(grid.get_child(0).get_global_rect().get_center())
			assert(m.builds[0].positions[gun] == Vector2i.ZERO)
			game.queue_free()
			await process_frame
	print("PASS: all 8 characters/CPU initial UI identity, two-cell click placement, unplaced starter stable across relic purchase")
	quit()
