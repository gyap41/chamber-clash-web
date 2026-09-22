extends RefCounted
const Actor = preload("res://scripts/combat/exploration_enemy.gd")
const ActorScene = preload("res://scenes/combat/player.tscn")
const Navigation = preload("res://scripts/ai/cpu_navigation.gd")

# A short flood from the entry ensures no furniture/wall overlap or isolated spawn.
static func spawn_positions(arena, arrival: Vector2) -> Array:
	var found: Array = []
	var pending := [Vector2i.ZERO]
	var seen := {Vector2i.ZERO:true}
	var cursor := 0
	while cursor < pending.size() and cursor < 16384:
		var cell: Vector2i = pending[cursor]
		cursor += 1
		var point := arrival+Vector2(cell)*32
		if point.distance_to(arrival) >= 260 and found.all(func(other): return point.distance_to(other) >= 128):
			found.append(point)
			if found.size() == 2: return found
		for offset in [Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT,Vector2i.UP]:
			var next: Vector2i = cell+offset
			if not seen.has(next) and Navigation.segment_clear(arena,point,arrival+Vector2(next)*32):
				seen[next] = true
				pending.append(next)
	return found

static func begin(game) -> void:
	if not game.encounters_enabled or game.floor_data.is_empty(): return
	var id: String = game.exploration.room_id
	if game.floor_data.rooms[id].role != "normal" or game.exploration.encounter_status == "cleared": return
	var positions := spawn_positions(game.arena,game.players[0].state.pos)
	if positions.size() != 2:
		push_error("No reachable enemy spawn: "+id)
		game.exploration.finish("abandoned")
		game.phase = "result"
		game.result = "敵の配置に失敗しました。再挑戦してください"
		return
	# Entry is outside CombatSession.step; the previous room has no live owners.
	for index in range(positions.size()):
		var actor = ActorScene.instantiate()
		actor.set_script(Actor)
		actor.name = "Sentry%d" % index
		game.arena.get_node("Players").add_child(actor)
		actor.prepare(positions[index])
		actor.telemetry = game.telemetry
		game.players.append(actor)
		game.fighters.append(actor.state)
		game.participant_config.append({"id":id+"/sentry%d" % index,"team":"enemies","controller":"enemy"})
	game.roster.configure(game.participant_config)
	for index in range(1,game.players.size()): game.bind_combat_actor(index)
	game.exploration.encounter_status = "active"

static func retire(game) -> void:
	# Clear *all* effects holding owner slots/references before recycling slots.
	game.clear_field_objects()
	game.submitted_commands.clear()
	for actor in game.players.slice(1):
		actor.get_parent().remove_child(actor)
		actor.queue_free()
	game.players.resize(1)
	game.fighters = [game.players[0].state]
	game.participant_config.resize(1)
	game.roster.configure(game.participant_config)
