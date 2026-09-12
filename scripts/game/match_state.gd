extends "res://scripts/game/run_inventory.gd"
const WIN_TARGET := Shop.WIN_TARGET
var scores: Array = []
func allows_field_acquisition() -> bool:
	return not ended and not settled and ready.all(func(value): return value)
# Duel/team series lifecycle. Inventory, money, acquisition and placement live in RunInventory.
func _init(value: int = 1, participant_count: int = 2) -> void:
	super(value,participant_count)
	scores = filled(participant_count,0)
func start_round() -> void:
	previous = builds.duplicate(true)
	settled = false
func finish(winner: int, players: Array) -> void:
	finish_team([] if winner < 0 else [winner],players)
func finish_team(winners: Array, players: Array) -> void:
	if settled or ended: return
	settled = true
	if winners.is_empty(): return
	for winner in winners: scores[winner] += 1
	if scores.max() >= WIN_TARGET:
		ended = true
		gold = filled(builds.size(),0)
		products = filled(builds.size(),[])
		refreshed = filled(builds.size(),false)
		expansion_bought = filled(builds.size(),false)
		next_card_id = 0
		builds = builds.map(func(_build): return _new_build())
		for i in range(builds.size()): _acquire(i,gun_token(start_guns[i]),"initial",0,"")
		previous = builds.duplicate(true)
		rewards = filled(builds.size(),[])
		temporary = filled(builds.size(),-1)
		purchase_counts = filled(builds.size(),0)
		ready = filled(builds.size(),false)
		return
	stage += 1
	refreshed = filled(builds.size(),false)
	expansion_bought = filled(builds.size(),false)
	ready = filled(builds.size(),false)
	for i in range(builds.size()):
		# Weapons were already stored at chest acquisition, including after a draw.
		temporary[i] = players[i].temporary_relic
		gold[i] += Shop.income(stage)
	generate_rewards()
