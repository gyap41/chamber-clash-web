extends "res://scripts/game/run_inventory.gd"
# No duel shop rolls, readiness or per-preparation purchase limits in exploration.
# Live editing stays closed; P1 edits a draft and applies a validated transaction.
var editing := false
func expansion_cells() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var usable := usable_cells(0)
	if usable.size() >= BuildGrid.MAX_AREA: return result
	for y in range(BuildGrid.MAX_GRID_SIZE.y):
		for x in range(BuildGrid.MAX_GRID_SIZE.x):
			var cell := Vector2i(x,y)
			if usable.has(cell): continue
			if [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN].any(func(offset): return usable.has(cell+offset)): result.append(cell)
	return result
func buy_cell(cell: Vector2i, price: int) -> bool:
	if ended or price < 0 or gold[0] < price or cell not in expansion_cells(): return false
	if not builds[0].has("extra_cells"): builds[0].extra_cells = []
	builds[0].extra_cells.append(cell)
	gold[0] -= price
	return true
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
