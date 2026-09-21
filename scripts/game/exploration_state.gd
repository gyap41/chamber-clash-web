extends RefCounted
# Runtime progression only; this is not a serialized save format.
const Start = preload("res://scripts/game/exploration_start.gd")
var seed_value: int
var room_id := "workshop_trial"
var status := "active"
var encounter_status := "active"
var inventory
func _init(value: int = 1) -> void:
	seed_value = value
	inventory = Start.create(value)
func finish(reason: String) -> bool:
	if status != "active" or reason not in ["dead","completed","abandoned"]: return false
	status = reason
	inventory.ended = true
	inventory.editing = false
	return true
func settle(player_alive: bool, enemies_alive: bool) -> void:
	if status != "active": return
	# Death takes priority over the last enemy dying in the same simulation frame.
	if not player_alive:
		finish("dead")
	elif encounter_status == "active" and not enemies_alive:
		encounter_status = "cleared"
		finish("completed")
