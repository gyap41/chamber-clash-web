extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func motion(at: Vector2, held: bool = false, delta: Vector2 = Vector2.ZERO) -> void:
	var event := InputEventMouseMotion.new()
	event.position = at
	event.global_position = at
	event.relative = delta
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if held else 0
	root.push_input(event,true)
func button(at: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = at
	event.global_position = at
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	root.push_input(event,true)
func run() -> void:
	var game = load("res://scenes/game/main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	var m = game.match_state
	# All catalog shapes must be connected, unique, positive offsets with an origin.
	for kind in ["gun","relic"]:
		for id in range(20):
			var shape: Array = m.shape_of(m.gun_token(id) if kind == "gun" else id)
			var visited := {Vector2i.ZERO:true}
			assert(Vector2i.ZERO in shape)
			if kind == "gun": assert(shape.size() >= 2)
			for cell in shape: assert(cell.x >= 0 and cell.y >= 0 and cell.x < 6 and cell.y < 6 and shape.count(cell) == 1)
			for pass_index in range(shape.size()):
				for cell in shape:
					for direction in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
						if visited.has(cell+direction): visited[cell] = true
			assert(visited.size() == shape.size())
	# Every real starter leaves room for both small reward items, with ordinary APIs.
	var characters = preload("res://scripts/catalog/character_catalog.gd")
	for char_id in range(characters.count()):
		game.new_match(char_id+1)
		m = game.match_state
		m.grant_start_weapon(0,characters.start_gun(char_id))
		assert(m.toggle(0,m.builds[0].owned[0]))
		m._set_products(0,[18,19])
		for id in [18,19]:
			assert(m.claim(0,id))
			assert(m.toggle(0,m.builds[0].owned.back()))
		assert(m.occupied_cells(0).size() <= 6)
		assert(m.equipped_relics(0) == [18,19])
	# A large stored S weapon must not leave CPU unarmed when a smaller gun fits.
	game.new_match(1)
	m = game.match_state
	m.stage = 2
	var planet: String = m.gun_token(15)
	m.builds[1] = {"owned":[planet,m.gun_token(0)],"equipped":[],"positions":{},"mods":{}}
	m.gold[1] = 0
	game.preparation.auto_prepare(1)
	assert(m.carried_guns(1) == [0] and planet in m.reserve_items(1))
	m.stage = 3
	m.ready[1] = false
	preload("res://tests/helpers/preparation.gd").rectangle(m,1)
	m.gold[1] = 0
	game.preparation.auto_prepare(1)
	assert(15 in m.carried_guns(1) and m.occupied_cells(1).size() >= 9)
	# Real GUI drag from the bottom-right of the 3x3 piece keeps its grab offset.
	m.builds[0] = {"owned":[planet],"equipped":[],"positions":{},"mods":{}}
	preload("res://tests/helpers/preparation.gd").rectangle(m)
	assert(m.place(0,planet,Vector2i.ZERO))
	var prep = game.preparation
	prep.turn = 0
	prep.cancel_placement()
	prep.refresh()
	await process_frame
	await process_frame
	var grid = prep.get_node("Root/Panel/Content/Cards/Equipment/Grid")
	var body = grid.get_child(14).get_child(0)
	assert(body.grab_offset == Vector2i(2,2))
	var source: Vector2 = body.get_global_rect().get_center()
	motion(source)
	button(source,true)
	motion(source+Vector2(20,0),true,Vector2(20,0))
	await process_frame
	assert(root.gui_is_dragging())
	var target: Vector2 = grid.get_child(15).get_global_rect().get_center()
	motion(target,true,target-source-Vector2(20,0))
	await process_frame
	button(target,false)
	await process_frame
	assert(m.builds[0].positions[planet] == Vector2i(1,0))
	assert(m.occupied_cells(0).size() == 9)
	var before: Dictionary = m.builds[0].duplicate(true)
	assert(not m.place(0,planet,Vector2i(2,0)) and m.builds[0] == before)
	# Moving into an unlocked extension uses all cells, not just its anchor.
	m.stage = 5
	assert(m.place_expansion(0,"rectangle",Vector2i(0,4)))
	assert(m.place(0,planet,Vector2i(0,3)))
	assert(m.occupied_cells(0).has(Vector2i(2,5)))
	game.queue_free()
	await process_frame
	print("PASS: all 40 footprints, every starter + small rewards, CPU large-weapon fallback, 3x3 GUI drag and extension movement")
	quit()
