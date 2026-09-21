extends "res://scripts/game/run_inventory.gd"
# No duel shop rolls, readiness or per-preparation purchase limits in exploration.
# P0 permits editing only while creating the initial loadout. P1 adds transactions.
var editing := false
func _init(value: int = 1) -> void:
	super(value,1,false)
	gold[0] = 0
func can_edit(i: int) -> bool:
	return valid_slot(i) and editing and not ended
func can_trade(_i: int) -> bool:
	return false
func allows_field_acquisition() -> bool:
	return not ended
func generate_rewards() -> void:
	pass
func confirm(_i: int) -> bool:
	return false
