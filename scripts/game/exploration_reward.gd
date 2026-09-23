extends RefCounted
const Navigation = preload("res://scripts/ai/cpu_navigation.gd")
const Weapons = preload("res://scripts/catalog/weapon_catalog.gd")

# First-clear and treasure rewards are independent guarantees.
static func ensure(game) -> bool:
	var progress = game.exploration
	if progress.status != "active" or progress.encounter_status != "cleared": return false
	if progress.room_states.values().any(func(value): return value.get("reward",{}).get("source","") == "first_clear"): return false
	return create(game,"first_clear",[4,6,19])

static func ensure_treasure(game) -> bool:
	if game.floor_data.is_empty() or game.exploration.status != "active": return false
	if game.floor_data.rooms[game.exploration.room_id].role != "treasure": return false
	return create(game,"treasure",[5,8,11,13])

static func create(game, source: String, pool: Array) -> bool:
	var progress = game.exploration
	var room: Dictionary = progress.room_state(progress.room_id)
	if room.has("reward"): return false
	var point = placement(game)
	if point == null:
		push_error("No reachable reward placement: "+progress.room_id)
		return false
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(progress.seed_value)+":"+source+":reward-v1")
	var item: int = pool[rng.randi_range(0,pool.size()-1)]
	room.reward = {"id":progress.room_id+":chest", "source":source,
		"kind":"weapon","item":item,"label":str(Weapons.definition(item).name),
		"pos":point,"state":"closed"}
	return true

# Search only reachable floor, preferring the room center and keeping interactions apart.
static func placement(game, excluded: Array = []) -> Variant:
	var start: Vector2 = game.players[0].state.pos
	var pending := [Vector2i.ZERO]
	var seen := {Vector2i.ZERO:true}
	var cursor := 0
	var best: Variant = null
	var best_score := INF
	while cursor < pending.size() and cursor < 16384:
		var cell: Vector2i = pending[cursor]
		cursor += 1
		var point := start+Vector2(cell)*32
		var door_clear: bool = game.room_data(game.exploration.room_id).doors.all(func(door): return point.distance_to(door.position) > 112 and point.distance_to(door.arrival) > 80)
		var score := point.distance_squared_to(game.arena.field_rect.get_center())
		if door_clear and score < best_score and excluded.all(func(other): return point.distance_to(other) >= 96) and not game.arena.solid(point,24):
			best = point
			best_score = score
		for offset in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			var next: Vector2i = cell+offset
			if not seen.has(next) and Navigation.segment_clear(game.arena,point,start+Vector2(next)*32):
				seen[next] = true
				pending.append(next)
	return best

static func current(game) -> Dictionary:
	return game.exploration.room_state(game.exploration.room_id).get("reward",{})

static func nearby(game) -> bool:
	var reward := current(game)
	return not reward.is_empty() and reward.state != "empty" and game.players[0].state.pos.distance_to(reward.pos) <= 64 and not game.arena.line_blocked(game.players[0].state.pos,reward.pos)
