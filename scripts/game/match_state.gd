extends RefCounted
const Generator = preload("res://scripts/game/reward_generator.gd")
const Weapons = preload("res://scripts/catalog/weapon_catalog.gd")
const Relics = preload("res://scripts/catalog/relic_catalog.gd")
const RelicShapes = preload("res://scripts/catalog/relic_shapes.gd")
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
	builds = [{"owned":[],"equipped":[],"main":-1,"mods":{},"positions":{}},{"owned":[],"equipped":[],"main":-1,"mods":{},"positions":{}}]
	previous = builds.duplicate(true)
	var rare: Array = generator.shuffled(Weapons.rarity_pool("B"))
	var choices := [rare[0],rare[1],generator.shuffled(Weapons.rarity_pool("A"))[0]]
	weapons = [choices.duplicate(),choices.duplicate()]
	generate_rewards()
func capacity() -> int:
	return [3,4,5,6,6][stage-1]
# P8 バックパックグリッド配置（配置基盤）。既存の段階制容量（上のcapacity()）は「装備できる
# 個数の上限」としてそのまま維持する——大量の既存テスト・CPU準備ロジック（auto_prepare）が
# この個数上限に依存しているため、着脱の可否そのものはここでは変えない。グリッドは各装備
# レリックが占有するマス（配置パズル・将来の隣接シナジー用の見た目レイヤー）を追加で管理する
# だけの層で、「面積そのものを着脱の制約にする」のは次段階（P8b/P8c）で改めて検討する。
# 段階別マス数は現行の個数上限3/4/5/6/6に対して余裕を持たせた仮の値（要playtest調整、
# claude/backpack-inventory-idea.md「段階1=3×2〜段階5=4×4程度」の叩き台をそのまま採用）。
const GRID_SIZES := [Vector2i(3,2),Vector2i(4,2),Vector2i(4,3),Vector2i(4,4),Vector2i(4,4)]
func grid_size() -> Vector2i:
	return GRID_SIZES[stage-1]
# 現在装備中のレリックが占有しているマスを {Vector2i(セル): レリックid} で返す。position未記録
# の装備品（例：テストがbuilds[i]を直接書き換えて構築した場合）は無視する——配置レイヤーは
# あくまで「置ければ置く」ベストエフォートの上乗せで、個数上限の判定には関与しない。
func occupied_cells(i: int, exclude_id: int = -1) -> Dictionary:
	var cells := {}
	var positions: Dictionary = builds[i].get("positions",{})
	for id in positions:
		if id == exclude_id or id not in builds[i].equipped: continue
		for offset in RelicShapes.shape(id): cells[positions[id]+offset] = id
	return cells
# idの形状をanchorへ置いた場合に、全マスがグリッド範囲内かつ空いているか。exclude_idは「すでに
# 置いてある自分自身」を一時的に除外するためのもの（移動時の自己衝突を避ける）。
func fits(i: int, id: int, anchor: Vector2i, exclude_id: int = -1) -> bool:
	var size := grid_size()
	var cells := occupied_cells(i,exclude_id)
	for offset in RelicShapes.shape(id):
		var cell: Vector2i = anchor+offset
		if cell.x < 0 or cell.y < 0 or cell.x >= size.x or cell.y >= size.y: return false
		if cells.has(cell): return false
	return true
# 読み順（左上→右下）で最初に空いている配置先を返す。CPU準備、および人間側のドラッグ操作を
# 経ない自動装備（報酬即時装備・フィールド仮装備相当）の見た目位置決めに使う。置き場がなけれ
# ば Vector2i(-1,-1)（この場合も装備自体は個数上限のみで成立し、位置は単に記録されない）。
func auto_place(i: int, id: int) -> Vector2i:
	var size := grid_size()
	for y in range(size.y):
		for x in range(size.x):
			var anchor := Vector2i(x,y)
			if fits(i,id,anchor): return anchor
	return Vector2i(-1,-1)
# ドラッグ＆ドロップなど、置き場所を明示的に指定する経路。既装備品の移動にも使う（この場合は
# 個数上限を再チェックしない）。位置が収まらなければ何もせずfalseを返す。
func place(i: int, id: int, anchor: Vector2i) -> bool:
	if ready[i] or id not in builds[i].owned: return false
	var already: bool = id in builds[i].equipped
	if not fits(i,id,anchor,id if already else -1): return false
	if not already:
		if builds[i].equipped.size() >= capacity(): return false
		builds[i].equipped.append(id)
	if not builds[i].has("positions"): builds[i]["positions"] = {}
	builds[i].positions[id] = anchor
	return true
func generate_rewards() -> void:
	var base: Array = generator.shuffled(Relics.SUPPORTED).slice(0,3)
	for i in range(2): rewards[i] = generator.candidates(base,builds[i].owned) + mod_candidates(i)
# P5: "レリック取得／主力改造" — when the current main weapon has unused modification
# branches, offer them as extra reward candidates alongside the usual relics (not in place
# of them; a candidate pool that includes zero mod tokens falls back to relics only, matching
# "対応武器がない場合は取得可能な報酬を提示する"). Represented as "mod:<weapon_id>:<key>"
# tokens so the existing int-keyed rewards[]/owned[] arrays don't need a parallel structure.
func mod_candidates(i: int) -> Array:
	var main_id: int = builds[i].get("main",-1)
	if main_id < 0 or not Weapons.moddable(main_id) or builds[i].get("mods",{}).has(main_id): return []
	var result: Array = []
	for mod in Weapons.mods_for(main_id): result.append(Weapons.mod_token(main_id,mod.key))
	return result
func reason(i: int, id) -> String:
	if i not in [0,1]: return "無効"
	if typeof(id) == TYPE_STRING: return mod_reason(i,id)
	if not Relics.supported(id): return "無効"
	if ready[i]: return "準備完了"
	if remaining[i] <= 0: return "報酬取得済み"
	if id in builds[i].owned: return "所持済み"
	if builds[i].owned.size() >= 8: return "所持庫8個が満杯：先に破棄"
	if id not in rewards[i] and id != temporary[i]: return "候補外"
	return ""
# A mod token can go stale mid-preparation if the player switches main away from the weapon
# it targets (set_main() doesn't prune rewards[]) — "現在の主力ではない" catches that rather
# than leaving a permanently-unclaimable candidate in the pool. See confirm()'s reason()-based
# gate below, which relies on this to avoid stalling on a token that can no longer be claimed.
func mod_reason(i: int, token: String) -> String:
	if ready[i]: return "準備完了"
	if remaining[i] <= 0: return "報酬取得済み"
	var parsed := Weapons.parse_mod_token(token)
	if parsed.is_empty(): return "無効"
	if parsed.weapon_id != builds[i].get("main",-1): return "現在の主力ではない"
	if builds[i].get("mods",{}).has(parsed.weapon_id): return "改造済み"
	if token not in rewards[i]: return "候補外"
	return ""
func claim(i: int, id) -> bool:
	if reason(i,id) != "": return false
	if typeof(id) == TYPE_STRING:
		var parsed := Weapons.parse_mod_token(id)
		if not builds[i].has("mods"): builds[i]["mods"] = {}
		# 改造は武器インスタンス（id）へ紐づく。owned/equipped には触れないため、所持庫8個
		# 枠は消費しない。主力を変更しても既存の改造は消えず、単に対象外になるだけ
		# （「旧武器の改造は移転しない」）。
		builds[i].mods[parsed.weapon_id] = parsed.mod_key
	else:
		builds[i].owned.append(id)
		if builds[i].equipped.size() < capacity():
			builds[i].equipped.append(id)
			_auto_position(i,id)
	remaining[i] -= 1
	if not initial: reward_counts[i] += 1
	return true
# claim()の即時装備・toggle()の装備側で共通の「置ければ置く」ベストエフォート位置決め。
# auto_place()が置き場を見つけられなくても装備自体は成立済みなので、位置は単に記録しない
# （見た目上は未配置のまま——個数上限だけで着脱可否が決まる設計はfits()/place()のコメント参照）。
func _auto_position(i: int, id: int) -> void:
	var anchor := auto_place(i,id)
	if anchor.x < 0: return
	if not builds[i].has("positions"): builds[i]["positions"] = {}
	builds[i].positions[id] = anchor
func toggle(i: int, id: int) -> bool:
	if ready[i] or id not in builds[i].owned: return false
	if id in builds[i].equipped:
		builds[i].equipped.erase(id)
		builds[i].get("positions",{}).erase(id)
	elif builds[i].equipped.size() < capacity():
		builds[i].equipped.append(id)
		_auto_position(i,id)
	else: return false
	return true
func discard(i: int, id: int) -> bool:
	if ready[i] or id not in builds[i].owned: return false
	builds[i].equipped.erase(id)
	builds[i].get("positions",{}).erase(id)
	builds[i].owned.erase(id)
	return true
func set_main(i: int, id: int) -> bool:
	if ready[i] or id not in weapons[i]: return false
	builds[i].main = id
	return true
func confirm(i: int) -> bool:
	if ready[i] or builds[i].main < 0: return false
	# reason(i,id)=="" means "still actionable" for either type of candidate — claimed relics
	# report "所持済み" and a mod token that's gone stale (main switched away) reports "現在の
	# 主力ではない", so both correctly stop blocking confirm() once resolved either way.
	if remaining[i] > 0 and rewards[i].any(func(id): return reason(i,id) == ""): return false
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
		builds = [{"owned":[],"equipped":[],"main":-1,"mods":{},"positions":{}},{"owned":[],"equipped":[],"main":-1,"mods":{},"positions":{}}]
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
