extends RefCounted
const Generator = preload("res://scripts/game/reward_generator.gd")
const Weapons = preload("res://scripts/catalog/weapon_catalog.gd")
const Relics = preload("res://scripts/catalog/relic_catalog.gd")
var generator
var seed_value: int
var scores := [0,0]
var stage := 1
var builds: Array = []
var previous: Array = []
var rewards: Array = [[],[]]
var remaining := [2,2]
var ready := [false,false]
var reward_counts := [0,0]
var weapons: Array = [[],[]]
var temporary := [-1,-1]
var initial := true
var settled := false
func _init(value: int = 1) -> void:
	seed_value = value
	generator = Generator.new(value)
	builds = [{"owned":[],"equipped":[],"main":-1},{"owned":[],"equipped":[],"main":-1}]
	previous = builds.duplicate(true)
	var rare: Array = generator.shuffled(Weapons.rarity_pool("B"))
	var choices := [rare[0],rare[1],generator.shuffled(Weapons.rarity_pool("A"))[0]]
	weapons = [choices.duplicate(),choices.duplicate()]
	generate_rewards()
func capacity() -> int:
	return [3,4,5,6,6][stage-1]
func generate_rewards() -> void:
	var base: Array = generator.shuffled(Relics.SUPPORTED).slice(0,3)
	for i in range(2): rewards[i] = generator.candidates(base,builds[i].owned)
func reason(i: int, id: int) -> String:
	if i not in [0,1] or not Relics.supported(id): return "無効"
	if ready[i]: return "準備完了"
	if remaining[i] <= 0: return "報酬取得済み"
	if id in builds[i].owned: return "所持済み"
	if builds[i].owned.size() >= 8: return "所持庫8個が満杯：先に破棄"
	if id not in rewards[i] and id != temporary[i]: return "候補外"
	return ""
func claim(i: int, id: int) -> bool:
	if reason(i,id) != "": return false
	builds[i].owned.append(id)
	if builds[i].equipped.size() < capacity(): builds[i].equipped.append(id)
	remaining[i] -= 1
	if not initial: reward_counts[i] += 1
	return true
func toggle(i: int, id: int) -> bool:
	if ready[i] or id not in builds[i].owned: return false
	if id in builds[i].equipped: builds[i].equipped.erase(id)
	elif builds[i].equipped.size() < capacity(): builds[i].equipped.append(id)
	else: return false
	return true
func discard(i: int, id: int) -> bool:
	if ready[i] or id not in builds[i].owned: return false
	builds[i].equipped.erase(id)
	builds[i].owned.erase(id)
	return true
func set_main(i: int, id: int) -> bool:
	if ready[i] or id not in weapons[i]: return false
	builds[i].main = id
	return true
func confirm(i: int) -> bool:
	if ready[i] or builds[i].main < 0: return false
	if remaining[i] > 0 and rewards[i].any(func(id): return id not in builds[i].owned): return false
	ready[i] = true
	return true
func start_round() -> void:
	previous = builds.duplicate(true)
	settled = false
func finish(winner: int, players: Array) -> void:
	if settled: return
	settled = true
	if winner < 0: return
	scores[winner] += 1
	if scores.max() >= 3:
		builds = [{"owned":[],"equipped":[],"main":-1},{"owned":[],"equipped":[],"main":-1}]
		previous = builds.duplicate(true)
		weapons = [[],[]]
		rewards = [[],[]]
		temporary = [-1,-1]
		remaining = [0,0]
		reward_counts = [0,0]
		ready = [false,false]
		return
	stage = mini(5,stage+1)
	initial = false
	ready = [false,false]
	remaining = [1,1]
	for i in range(2):
		weapons[i] = players[i].inventory.map(func(w): return w.id)
		if builds[i].main not in weapons[i]: builds[i].main = weapons[i][0]
		temporary[i] = players[i].temporary_relic
	generate_rewards()
