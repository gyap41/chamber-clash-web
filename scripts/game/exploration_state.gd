extends RefCounted
# Runtime progression only; this is not a serialized save format.
const Start = preload("res://scripts/game/exploration_start.gd")
var seed_value: int
var room_id := "workshop_trial"
var visited_rooms: Dictionary = {"workshop_trial":true}
var status := "active"
var room_states: Dictionary = {}
var encounter_status: String:
	get: return room_state(room_id).encounter
	set(value): room_state(room_id).encounter = value
var inventory
var weapon_bank: Dictionary = {}
var collected_loot: Dictionary = {}
func _init(value: int = 1) -> void:
	seed_value = value
	inventory = Start.create(value)
func room_state(instance_id: String) -> Dictionary:
	if not room_states.has(instance_id):
		room_states[instance_id] = {"template_id":"","encounter":"none"}
	return room_states[instance_id]
func enter_room(instance_id: String, template_id: String) -> void:
	room_id = instance_id
	room_state(instance_id).template_id = template_id
	visited_rooms[instance_id] = true
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
