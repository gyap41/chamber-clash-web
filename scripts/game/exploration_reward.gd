extends RefCounted
const Navigation = preload("res://scripts/ai/cpu_navigation.gd")
const Weapons = preload("res://scripts/catalog/weapon_catalog.gd")

# P4 vertical slice: one guaranteed equipment chest after the first cleared battle.
static func ensure(game) -> bool:
	var progress = game.exploration
	if progress.status != "active" or progress.encounter_status != "cleared": return false
	if progress.room_states.values().any(func(value): return value.has("reward")): return false
	var start: Vector2 = game.players[0].state.pos
	var pending := [Vector2i.ZERO]
	var seen := {Vector2i.ZERO:true}
	var cursor := 0
	while cursor < pending.size() and cursor < 16384:
		var cell: Vector2i = pending[cursor]
		cursor += 1
		var point := start+Vector2(cell)*32
		var door_clear: bool = game.room_data(progress.room_id).doors.all(func(door): return point.distance_to(door.position) > 112 and point.distance_to(door.arrival) > 80)
		if door_clear and not game.arena.solid(point,24):
			var rng := RandomNumberGenerator.new()
			rng.seed = hash(str(progress.seed_value)+":first-clear-reward-v1")
			var item: int = [4,6,19][rng.randi_range(0,2)]
			progress.room_state(progress.room_id).reward = {"id":progress.room_id+":clear_chest",
				"kind":"weapon","item":item,"label":str(Weapons.definition(item).name),
				"pos":point,"state":"closed"}
			return true
		for offset in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			var next: Vector2i = cell+offset
			if not seen.has(next) and Navigation.segment_clear(game.arena,point,start+Vector2(next)*32):
				seen[next] = true
				pending.append(next)
	return false

static func current(game) -> Dictionary:
	return game.exploration.room_state(game.exploration.room_id).get("reward",{})

static func nearby(game) -> bool:
	var reward := current(game)
	return not reward.is_empty() and reward.state != "empty" and game.players[0].state.pos.distance_to(reward.pos) <= 64 and not game.arena.line_blocked(game.players[0].state.pos,reward.pos)
