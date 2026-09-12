extends RefCounted
# Slots are local storage addresses; participant IDs and teams are independent identities.
var participants: Array = []
func configure(entries: Array) -> void:
	var ids := {}
	for entry in entries:
		assert(not ids.has(entry.id), "Duplicate participant ID")
		ids[entry.id] = true
	participants = entries.duplicate(true)
func hostile(a: int, b: int) -> bool:
	return a >= 0 and b >= 0 and a < participants.size() and b < participants.size() and participants[a].team != participants[b].team
func enemies(slot: int, players: Array) -> Array:
	var found: Array = []
	for i in range(players.size()):
		if hostile(slot,i) and players[i].state.hp > 0: found.append(players[i])
	return found
func nearest(slot: int, players: Array, pos: Vector2):
	var target = null
	var distance := INF
	for enemy in enemies(slot,players):
		var d: float = pos.distance_squared_to(enemy.state.pos)
		if d < distance:
			target = enemy
			distance = d
	return target
