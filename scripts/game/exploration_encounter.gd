extends RefCounted
const Boss = preload("res://scripts/combat/furnace_warden.gd")
const Actor = preload("res://scripts/combat/exploration_enemy.gd")
const Quillback = preload("res://scripts/combat/quillback.gd")
const Lizard = preload("res://scripts/combat/fire_pouch_lizard.gd")
const ActorScene = preload("res://scenes/combat/player.tscn")
const Navigation = preload("res://scripts/ai/cpu_navigation.gd")

# Composition follows room size; the first fight remains a melee-only introduction.
static func composition(arena, introduced: bool) -> Array:
	var area: float = arena.field_rect.get_area()
	var count := 3 if not introduced else (3 if area < 600000 else (4 if area < 900000 else (5 if area < 1150000 else 6)))
	var ids: Array = []
	for i in range(count):
		ids.append("fire_pouch_lizard" if introduced and i%3 == 1 else "workshop_sentry")
	if introduced and count >= 5: ids[2] = "quillback"
	return ids

# Flood reachable floor, then spread approach angles instead of taking the first BFS cells.
static func spawn_positions(arena, arrival: Vector2, count: int = 3) -> Array:
	var candidates: Array = []
	var found: Array = []
	var pending := [Vector2i.ZERO]
	var seen := {Vector2i.ZERO:true}
	var cursor := 0
	while cursor < pending.size() and cursor < 16384:
		var cell: Vector2i = pending[cursor]
		cursor += 1
		var point := arrival+Vector2(cell)*32
		if point.distance_to(arrival) >= 260 and not arena.solid(point,20): candidates.append(point)
		for offset in [Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT,Vector2i.UP]:
			var next: Vector2i = cell+offset
			if not seen.has(next) and Navigation.segment_clear(arena,point,arrival+Vector2(next)*32):
				seen[next] = true
				pending.append(next)
	for index in range(count):
		var best: Variant = null
		var best_score := -INF
		for point in candidates:
			if not found.all(func(other): return point.distance_to(other) >= 160): continue
			var direction: Vector2 = (point-arrival).normalized()
			var angular := 2.0
			for other in found: angular = minf(angular,1.0-direction.dot((other-arrival).normalized()))
			var preferred := 420.0 if index%3 == 1 else 330.0
			var score: float = angular*240.0-absf(point.distance_to(arrival)-preferred)
			if score > best_score:
				best = point
				best_score = score
		if best == null: return found
		found.append(best)
	return found

static func begin(game) -> void:
	if not game.encounters_enabled or game.floor_data.is_empty(): return
	var id: String = game.exploration.room_id
	if game.floor_data.rooms[id].role not in ["normal","boss"] or game.exploration.encounter_status == "cleared": return
	var room_state: Dictionary = game.exploration.room_state(id)
	if not room_state.has("enemy_ids"):
		var introduced: bool = game.exploration.room_states.values().any(func(value): return value.has("enemy_ids"))
		room_state.enemy_ids = ["furnace_warden"] if game.floor_data.rooms[id].role == "boss" else composition(game.arena,introduced)
	var positions := spawn_positions(game.arena,game.players[0].state.pos,room_state.enemy_ids.size())
	if game.floor_data.rooms[id].role == "boss":
		positions = [Vector2(game.arena.field_rect.get_center().x,game.arena.field_rect.end.y-430)]
		if game.arena.solid(positions[0],44): positions.clear()
	if positions.size() != room_state.enemy_ids.size():
		push_error("No reachable enemy spawn: "+id)
		game.exploration.finish("abandoned")
		game.phase = "result"
		game.result = "敵の配置に失敗しました。再挑戦してください"
		return
	# Entry is outside CombatSession.step; the previous room has no live owners.
	for index in range(positions.size()):
		var actor = ActorScene.instantiate()
		actor.set_script(Boss if room_state.enemy_ids[index] == "furnace_warden" else Quillback if room_state.enemy_ids[index] == "quillback" else (Lizard if room_state.enemy_ids[index] == "fire_pouch_lizard" else Actor))
		actor.name = "Enemy%d" % index
		game.arena.get_node("Players").add_child(actor)
		actor.prepare(positions[index])
		actor.telemetry = game.telemetry
		game.players.append(actor)
		game.fighters.append(actor.state)
		game.participant_config.append({"id":id+"/enemy%d" % index,"team":"enemies","controller":"enemy"})
	game.roster.configure(game.participant_config)
	for index in range(1,game.players.size()): game.bind_combat_actor(index)
	game.exploration.encounter_status = "active"
	if game.floor_data.rooms[id].role == "boss": game.BossFlow.begin_intro(game)

static func retire(game) -> void:
	game.sound.update_boss_engine(false)
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
