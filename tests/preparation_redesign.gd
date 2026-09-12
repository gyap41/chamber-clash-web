extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var game = load("res://scenes/game/main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.new_match(42)
	var m = game.match_state
	var prep = game.preparation
	m._set_products(0,["gun:1","gun:2",1,4,18])
	prep.refresh()
	await process_frame
	await process_frame
	var cards = prep.get_node("Root/Panel/Content/Cards")
	var shop = cards.get_node("Rewards/Scroll")
	assert(shop.get_node("List").get_child_count() == 5)
	for card in shop.get_node("List").get_children():
		assert(shop.get_global_rect().encloses(card.get_global_rect()))
	var before: Array = m.builds.duplicate(true)
	var gold: Array = m.gold.duplicate()
	prep.inspect_offer(m.products[0][2].id)
	assert(prep.selected_reward and prep.placement_entry == null)
	assert(m.builds == before and m.gold == gold)
	assert("装填倍率" in prep.detail_description.text)
	prep.buy_selected()
	var purchased = m.builds[0].owned.back()
	assert(m.relic_id(purchased) == 1 and prep.selected_detail == purchased)
	assert(prep.placement_entry == null and m.builds[0].equipped.is_empty())
	# The footer must agree with the battle model for every stacked HP count.
	for count in range(4):
		m.builds[0] = {"owned":[],"equipped":[],"positions":{},"mods":{}}
		preload("res://tests/helpers/preparation.gd").rectangle(m)
		for i in range(count):
			var token := "relic:4:%d" % i
			m.builds[0].owned.append(token)
			assert(m.place(0,token,m.auto_place(0,token)))
		prep.refresh()
		var hp: float = game.players[0].max_hp + count * float(prep.Relics.definition(4).hp_bonus)
		assert(prep.get_node("Root/Panel/Content/Notice").text.begins_with("HP %s / %s" % [str(hp),str(hp)]))
	m.temporary[0] = 18
	prep.refresh()
	var warnings: String = prep.get_node("Root/Panel/Content/Summary").text
	assert("武器未配置" in warnings and "未確保の無料品" in warnings)
	prep.open_expansions()
	assert(cards.get_node("Equipment/ExpansionPopup").visible)
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	root.push_input(escape,true)
	assert(not cards.get_node("Equipment/ExpansionPopup").visible)
	game.queue_free()
	await process_frame
	print("PASS: five visible products, inspection is read-only, purchase selects without placement, stacked HP, both warnings, Esc closes expansion")
	quit()
