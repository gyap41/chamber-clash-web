extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var game = load("res://scenes/game/main.tscn").instantiate()
	root.add_child(game)
	preload("res://tests/helpers/battle.gd").passive_opponents(game)
	game.set_physics_process(false)
	var m = game.match_state
	for stage in range(1,10):
		m.stage = stage
		assert(m.capacity() == 8 and m.grid_size() == Vector2i(6,6))
	# Bounding rectangle contains holes: neither anchoring nor spanning one is legal.
	m.builds[0] = {"owned":[18,6,4],"equipped":[],"positions":{},"mods":{}}
	preload("res://tests/helpers/preparation.gd").rectangle(m)
	assert(m.place_expansion(0,"elbow",Vector2i(4,0)))
	assert(not m.fits(0,18,Vector2i(5,2)))
	assert(not m.fits(0,6,Vector2i(4,2)))
	assert(m.place(0,18,Vector2i(5,1)))
	assert(m.place(0,4,Vector2i(4,2)))
	var original: Dictionary = m.builds[0].duplicate(true)
	assert(not m.place(0,4,Vector2i(5,2)))
	assert(m.builds[0] == original)
	assert(m.fits(0,6,Vector2i(4,0)))
	# Auto-placement visits the same usable set, excluding holes even when nearly full.
	m.builds[0] = {"owned":[],"equipped":[],"positions":{},"mods":{}}
	preload("res://tests/helpers/preparation.gd").rectangle(m)
	assert(m.place_expansion(0,"elbow",Vector2i(4,0)))
	for index in range(23):
		var token := "relic:18:%d" % index
		m.builds[0].owned.append(token)
		var anchor: Vector2i = m.auto_place(0,token)
		if index < 22:
			assert(m.usable_cells().has(anchor) and m.place(0,token,anchor))
		else: assert(anchor == Vector2i(-1,-1))
	assert(m.occupied_cells(0).size() == 22)
	m.stage = 1
	m.builds[0] = {"owned":[18],"equipped":[],"positions":{},"mods":{}}
	game.preparation.refresh()
	await process_frame
	await process_frame
	var grid = game.preparation.get_node("Root/Panel/Content/Cards/Equipment/Grid")
	assert(grid.get_child_count() == 36 and grid.columns == 6)
	assert(grid.size == Vector2(320,320))
	assert(not grid.get_child(5)._can_drop_data(Vector2.ZERO,{"entry":18}))
	assert(not game.preparation.preview_at(18,Vector2i(5,0)))
	assert("未開放" in game.preparation.detail_path().get_node("Status").text)
	# A completely occupied bag rejects field relics even with few relic instances.
	m.stage = 1
	m.builds[0] = {"owned":[m.gun_token(8)],"equipped":[],"positions":{},"mods":{}}
	assert(m.place(0,m.gun_token(8),Vector2i.ZERO))
	var player = game.players[0]
	player.apply_build(m.builds[0],m.capacity(),true,m.usable_cells())
	assert(player.relics.is_empty() and player.acquire_temporary(18))
	# Fill the two remaining cells with a vertical weapon for the full-bag boundary.
	m.builds[0].owned.append(m.gun_token(12))
	assert(m.place(0,m.gun_token(12),Vector2i(3,0)))
	player.apply_build(m.builds[0],m.capacity(),true,m.usable_cells())
	assert(not player.acquire_temporary(18))
	# Reserve capacity includes only unplaced items; a failed removal keeps its position.
	m.stage = 4
	m.builds[0] = {"owned":[],"equipped":[],"positions":{},"mods":{}}
	for index in range(9): m.builds[0].owned.append("relic:18:%d" % index)
	var equipped = m.builds[0].owned[0]
	assert(m.place(0,equipped,Vector2i.ZERO))
	assert(m.reserve_full(0) and m.builds[0].owned.size() == 9)
	original = m.builds[0].duplicate(true)
	assert(not m.toggle(0,equipped) and m.builds[0] == original)
	assert(not m.arrange(0,[]) and m.builds[0] == original)
	assert(m.place(0,m.builds[0].owned[1],Vector2i(1,0)))
	assert(m.toggle(0,equipped) and m.reserve_full(0))
	assert(m.discard(0,equipped) and not m.reserve_full(0))
	# CPU must not overflow reserve while rearranging or claiming another duplicate.
	m.builds[1] = m.builds[0].duplicate(true)
	m.ready[1] = false
	m._set_products(1,[18,19])
	game.preparation.auto_prepare(1)
	assert(m.ready[1] and m.reserve_items(1).size() <= m.RESERVE_CAPACITY)
	assert(m.builds[1].owned.size() > 8)
	for entry in m.builds[1].equipped:
		assert(m.fits(1,entry,m.builds[1].positions[entry],entry))
	# Field weapons carry over only into reserve, never over its limit.
	m.ready = [false,false]
	m.builds[0] = {"owned":[],"equipped":[],"positions":{},"mods":{}}
	for n in range(8): m.builds[0].owned.append("relic:18:%d" % n)
	player.apply_build(m.builds[0],m.capacity(),true,m.usable_cells())
	assert(player.add_gun(8))
	m.start_round()
	m.finish(0,game.players)
	assert(m.reserve_items(0).size() == 8 and m.gun_token(8) not in m.builds[0].owned)
	# Eight carried weapons is a separate input/HUD limit; preview and place agree.
	m.stage = 5
	m.ready[0] = false
	m.builds[0] = {"owned":[],"equipped":[],"positions":{},"mods":{}}
	preload("res://tests/helpers/preparation.gd").rectangle(m)
	assert(m.place_expansion(0,"elbow",Vector2i(4,0)))
	for gun_id in [0,3,4,1,7,12,18,6,13]: m.builds[0].owned.append(m.gun_token(gun_id))
	assert(m.arrange(0,m.builds[0].owned.duplicate()))
	assert(m.carried_guns(0).size() == 8 and m.reserve_items(0).size() == 1)
	var ninth = m.reserve_items(0)[0]
	assert(not m.fits(0,ninth,Vector2i(0,3)) and not m.place(0,ninth,Vector2i(0,3)))
	game.queue_free()
	await process_frame
	print("PASS: 6x6 canvas, monotonic shaped expansion, locked holes, atomic rejection, auto-placement and UI bounds")
	quit()
