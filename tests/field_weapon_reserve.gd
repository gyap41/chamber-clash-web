extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func launch(game) -> void:
	game.new_match(505)
	for i in range(2):
		assert(game.match_state.place(i,"gun:0",Vector2i.ZERO))
		assert(game.match_state.confirm(i))
	game.launch_round()
	game.supplies.reset()
	game.players[0].state.pos = Vector2(170,100)
	game.players[1].state.pos = Vector2(900,100)
func chest(game, id: int, index: int = 0):
	var item = game.supplies.put_item("weapon",id,game.players[index].state.pos)
	assert(item != null)
	item.age = .6
	return item
func run() -> void:
	var game = load("res://scenes/game/main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	var p = game.players[0]
	var q = game.players[1]
	launch(game)
	var m = game.match_state
	p.weapon().clip = 3
	p.weapon().reserve = 8
	p.start_reload()
	var loadout: Array = p.inventory.duplicate(true)
	var state: Dictionary = p.state.duplicate(true)
	var before: Dictionary = m.builds[0].positions.duplicate()
	var item = chest(game,37)
	game.supplies.interact(0)
	game.supplies.step(1.51)
	assert(p.inventory == loadout and p.state == state)
	assert(m.reserve_items(0) == ["gun:37"] and not p.owns(37))
	assert(m.builds[0].positions == before and m.gold[0] == 12)
	assert(m.builds[0].acquisitions["gun:37"] == {"source":"field","paid":0,"card_id":""})
	assert("次の準備" in game.supplies.notice)
	assert(not m.place(0,"gun:37",Vector2i.ZERO) and not m.sell(0,"gun:37"))
	# Duplicate in reserve and carried duplicates never refill ammo or consume the chest.
	for id in [37,0]:
		item = chest(game,id)
		assert(not game.supplies.acquire(0,item,true) and not item.used)
		assert(p.inventory == loadout)
		item.refresh(game.players,.6,1.5)
		assert("所持済み" in item.get_node("Hint").text)
		game.supplies.reset()
	# Capacity is reserve slots, not carried slots or the item's future grid area.
	for id in range(30,37):
		item = chest(game,id)
		assert(game.supplies.acquire(0,item,true))
		game.supplies.reset()
	assert(m.reserve_items(0).size() == 8 and p.inventory == loadout)
	item = chest(game,15)
	assert(not game.supplies.acquire(0,item,true) and not item.used)
	assert("満杯" in p.field_weapon_reason(15))
	# No cross-player lock or capacity leak: P2 may collect the rejected chest.
	q.state.pos = p.state.pos
	assert(game.supplies.acquire(1,item,true))
	assert(m.reserve_items(1) == ["gun:15"] and not q.owns(15))
	# A real draw replays the same loadout while retaining the acquired reserve.
	launch(game)
	m = game.match_state
	item = chest(game,30)
	assert(game.supplies.acquire(0,item,true))
	game.remaining = .001
	game._physics_process(.002)
	assert(game.result == "DRAW" and m.reserve_items(0) == ["gun:30"])
	game.reset_round()
	assert(game.phase == "play" and m.stage == 1 and m.gold == [12,12])
	assert(p.inventory.size() == 1 and p.weapon().id == 0 and not p.owns(30))
	assert(m.reserve_items(0) == ["gun:30"])
	# Victory unlocks preparation, and only explicit placement equips the pickup.
	q.state.hp = 0
	game._physics_process(.001)
	game.reset_round()
	assert(game.phase == "prepare" and m.reserve_items(0) == ["gun:30"])
	assert(m.place(0,"gun:30",Vector2i(0,1)))
	for i in range(2): assert(m.confirm(i))
	game.launch_round()
	assert(p.owns(30) and p.inventory.size() == 2)
	assert(p.inventory[1].clip == 8 and p.inventory[1].reserve == 40)
	# Final victory and a new match discard stored field loot.
	item = chest(game,31)
	assert(game.supplies.acquire(0,item,true))
	m.scores = [4,0]
	game.scores = m.scores
	q.state.hp = 0
	game._physics_process(.001)
	assert(m.ended and "gun:31" not in m.builds[0].owned)
	game.reset_round()
	assert(game.phase == "prepare" and game.match_state.reserve_items(0) == ["gun:0"])
	# CPU ignores full/owned reserve even for a legendary chest.
	launch(game)
	m = game.match_state
	for id in range(30,38): assert(m.store_field_weapon(1,id))
	item = chest(game,15,1)
	game.CpuAI.decide(game,q,p,.016)
	assert(item.opening_player == -1 and not item.used)
	assert(q.inventory.size() == 1 and q.weapon().id == 0)
	print("PASS: reserve-only pickup, unchanged active state, duplicate/capacity rejection, symmetric storage, draw persistence, explicit next-round equip, final/new-match reset, CPU full guard")
	game.queue_free()
	quit()
