extends "res://scripts/game/run_inventory.gd"
# No duel shop rolls, readiness or per-preparation purchase limits in exploration.
# Live editing stays closed; P1 edits a draft and applies a validated transaction.
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

func store_field_relic(id: int) -> bool:
	if ended or reserve_full(0) or not Relics.supported(id): return false
	if not Relics.stackable(id) and id in Items.relic_ids(builds[0].owned): return false
	_acquire(0,id,"field",0,"")
	return true
