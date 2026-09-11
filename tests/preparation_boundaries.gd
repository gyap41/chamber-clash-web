extends SceneTree
const Match = preload("res://scripts/game/match_state.gd")
const CpuPreparation = preload("res://scripts/ai/cpu_preparation.gd")
const BuildGrid = preload("res://scripts/game/build_grid.gd")
const Items = preload("res://scripts/game/item_identity.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	# Preparation policy can complete a match without creating any UI or battle nodes.
	for seed_value in range(20):
		var state = Match.new(seed_value)
		for round_index in range(9):
			for i in range(2):
				CpuPreparation.auto_prepare(state,i)
				assert(state.ready[i] and state.gold[i] >= 0)
				assert(not state.carried_guns(i).is_empty())
				assert(state.reserve_items(i).size() <= Match.RESERVE_CAPACITY)
				assert(state.capacity(i) <= BuildGrid.MAX_AREA)
				var area := 0
				for entry in state.builds[i].equipped:
					area += BuildGrid.shape_of(entry).size()
					assert(state.fits(i,entry,state.builds[i].positions[entry],entry))
				assert(state.occupied_cells(i).size() == area)
			state.start_round()
			state.finish(round_index % 2,[{"temporary_relic":-1},{"temporary_relic":-1}])
		assert(state.ended and state.scores == [5,4] and state.gold == [0,0])
	print("PASS: scene-independent CPU preparation, legal packing and economy across 20 full matches")

	# Both boundaries use reading order, ignore unequipped/stale positions, and retain
	# distinct stacked relic identities. Applying a build must not mutate that build.
	var state = Match.new(42)
	var first := Items.relic_token(18,0)
	var second := Items.relic_token(18,1)
	state.builds[0] = {
		"owned":["gun:0","gun:12","gun:1",first,second],
		"equipped":["gun:0",second,"gun:12",first],
		"positions":{"gun:0":Vector2i(1,0),"gun:12":Vector2i.ZERO,
			"gun:1":Vector2i(3,0),first:Vector2i(1,1),second:Vector2i(2,1)},
		"mods":{},"bag_expansions":[]
	}
	var before: Dictionary = state.builds[0].duplicate(true)
	var player = load("res://scenes/combat/player.tscn").instantiate()
	root.add_child(player)
	player.apply_build(state.builds[0],state.capacity(),true,state.usable_cells())
	assert(player.inventory.map(func(entry): return entry.id) == [12,0])
	assert(state.carried_guns(0) == [12,0])
	assert(player.relics == [18,18] and player.field_occupied.size() == 6)
	assert(player.field_occupied[Vector2i(1,1)] == first)
	assert(player.field_occupied[Vector2i(2,1)] == second)
	assert(player.field_relic_reason(4).is_empty())
	assert(not player.field_relic_reason(6).is_empty())
	assert(not state.fits(0,18,Vector2i(-1,0)))
	assert(not state.fits(0,18,Vector2i(4,0)))
	assert(state.fits(0,first,Vector2i(1,1),first))
	assert(not state.fits(0,first,Vector2i(2,1),first))
	assert(state.builds[0] == before)
	assert(not Items.same_entry(18,first) and not Items.same_entry(first,second))
	player.free()
	print("PASS: shared preparation/combat geometry, reading order, stacked identity and immutable build boundary")
	quit()
