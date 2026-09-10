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
	var size := grid_size()
	return size.x * size.y
# P8x グリッド拡張基盤：容量モデルをグリッドの面積そのものに統合した（P8時点の「個数上限は
# 変更しない」という設計判断を撤回）。capacity()は「グリッドの総マス数」を返す補助関数に
# なり、着脱可否そのものはplace()/toggle()/claim()がfits()/auto_place()（実際にその形状が
# 収まる空きマスがあるか）だけで判定する。個数がいくつであっても、装備中レリックの形状の
# 合計占有マスがグリッドに収まる限り装備できる——強いレリックほど複数マスを取るぶん、結果的
# に「数」を圧迫する。段階別マス数はP8時点の仮値をそのまま流用（要playtest調整、
# claude/backpack-inventory-idea.md「段階1=3×2〜段階5=4×4程度」の叩き台）。
const GRID_SIZES := [Vector2i(3,2),Vector2i(4,2),Vector2i(4,3),Vector2i(4,4),Vector2i(4,4)]
func grid_size() -> Vector2i:
	return GRID_SIZES[stage-1]
# 現在装備中のレリックが占有しているマスを {Vector2i(セル): レリックid} で返す。position未記録
# の装備品は無視する——place()/toggle()/claim()を経由して装備したものは必ずpositionsに記録
# されるため、この経路を通らずにbuilds[i]を直接書き換えるコード（テスト等）だけが対象になる。
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
# 経ない自動装備（報酬即時装備）の位置決めに使う。置き場がなければVector2i(-1,-1)——P8xでは
# これがそのまま「装備できない（グリッド満杯）」の判定にもなる（_equip_if_fits()参照）。
func auto_place(i: int, id: int) -> Vector2i:
	var size := grid_size()
	for y in range(size.y):
		for x in range(size.x):
			var anchor := Vector2i(x,y)
			if fits(i,id,anchor): return anchor
	return Vector2i(-1,-1)
# ドラッグ＆ドロップなど、置き場所を明示的に指定する経路。既装備品の移動にも使う。P8xにより
# 着脱可否はfits()（実際にその位置へ収まるか）だけで決まる——個数上限は撤廃済み。
func place(i: int, id: int, anchor: Vector2i) -> bool:
	if ready[i] or id not in builds[i].owned: return false
	var already: bool = id in builds[i].equipped
	if not fits(i,id,anchor,id if already else -1): return false
	if not already: builds[i].equipped.append(id)
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
		_equip_if_fits(i,id)
	remaining[i] -= 1
	if not initial: reward_counts[i] += 1
	return true
# claim()の即時装備・toggle()の装備側で共通の「収まるなら装備する」処理。P8xでグリッドの
# 空きマスが実際の制約になったため、旧来の「置き場がなくても個数上限内なら装備は成立する」
# という抜け道は廃止した——装備が成立する＝実際にグリッドへ置ける、という一本の基準に統一する。
func _equip_if_fits(i: int, id: int) -> bool:
	var anchor := auto_place(i,id)
	if anchor.x < 0: return false
	builds[i].equipped.append(id)
	if not builds[i].has("positions"): builds[i]["positions"] = {}
	builds[i].positions[id] = anchor
	return true
func toggle(i: int, id: int) -> bool:
	if ready[i] or id not in builds[i].owned: return false
	if id in builds[i].equipped:
		builds[i].equipped.erase(id)
		builds[i].get("positions",{}).erase(id)
	elif not _equip_if_fits(i,id): return false
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
