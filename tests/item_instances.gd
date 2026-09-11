extends SceneTree
const Match = preload("res://scripts/game/match_state.gd")
const Items = preload("res://scripts/game/item_identity.gd")
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var game = load("res://scenes/game/main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	var m = game.match_state
	m.builds[0].owned = [m.gun_token(0),0,4]
	assert(m.place(0,0,Vector2i.ZERO))
	m.migrate_relic_instances(0)
	var first = m.builds[0].owned[1]
	assert(Items.relic_id(first) == 0)
	assert(m.builds[0].positions[first] == Vector2i.ZERO)
	var snapshot: Dictionary = m.builds[0].duplicate(true)
	m.migrate_relic_instances(0)
	assert(m.builds[0] == snapshot)
	# Two objects of the same type must move and discard independently.
	var second := Items.relic_token(0,99)
	m.builds[0].owned.append(second)
	assert(m.place(0,second,Vector2i(0,1)))
	assert(not m.place(0,first,Vector2i(0,1)))
	assert(m.place(0,first,Vector2i(1,0)))
	assert(m.equipped_relics(0) == [0,0])
	game.players[0].apply_build(m.builds[0],m.capacity(),true)
	assert(game.players[0].relics == [0,0])
	game.preparation.refresh()
	assert(game.preparation.entry_info(first) == game.preparation.entry_info(second))
	assert(m.discard(0,first))
	assert(m.builds[0].positions[second] == Vector2i(0,1))
	assert(m.equipped_relics(0) == [0])
	# Reward rules still forbid duplicates until stacking is explicitly opened.
	m.rewards[0] = [0,1,2]
	assert(m.reason(0,0) == "所持済み")
	assert(game.preparation.claim(1))
	var acquired = m.builds[0].owned.back()
	assert(Items.relic_id(acquired) == 1 and typeof(acquired) == TYPE_STRING)
	assert(game.preparation.placement_entry == acquired)
	m.start_round()
	assert(m.discard(0,acquired) and acquired in m.previous[0].owned)
	m.migrate_relic_instances(1)
	game.preparation.auto_prepare(1)
	assert(m.ready[1])
	assert(m.builds[1].owned.any(func(e): return typeof(e) == TYPE_STRING and Items.is_relic(e)))
	for invalid in ["relic:x:1","relic:0","mod:0:a","gun:0",-1]: assert(not Items.is_relic(invalid))
	game.queue_free()
	await process_frame
	print("PASS: item identity migration, duplicate movement/discard, combat/UI boundary, acquisition and round snapshot")
	quit()
