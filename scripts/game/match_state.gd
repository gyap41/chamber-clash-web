extends RefCounted
const Generator = preload("res://scripts/game/reward_generator.gd")
const Weapons = preload("res://scripts/catalog/weapon_catalog.gd")
const Relics = preload("res://scripts/catalog/relic_catalog.gd")
const RelicShapes = preload("res://scripts/catalog/relic_shapes.gd")
const WeaponShapes = preload("res://scripts/catalog/weapon_shapes.gd")
const Items = preload("res://scripts/game/item_identity.gd")
var generator
var seed_value: int
var scores := [0,0]
var stage := 1
var builds: Array = []
var previous: Array = []
var rewards: Array = [[],[]]
var claimed_candidates: Array = [[],[]]
var remaining := [2,2]
var ready := [false,false]
var reward_counts := [0,0]
var temporary := [-1,-1]
var initial := true
var settled := false
# P8z 装備モデルの統合：所持庫（owned）と装備（equipped/positions）は武器とレリックの共通の
# 置き場になった。レリックは素のint、武器は "gun:<id>" という文字列トークンで表す（報酬の改造
# トークン "mod:<id>:<key>" と同じ書き方で、既存の配列・辞書構造を作り直さずに済ませるため）。
# 「主力（build.main）」と「サイドアームの自動付与」はこのフェーズで廃止し、グリッドに置いた
# 武器がそのラウンドの携行武器になる。武器を1丁も置かなければ丸腰で、近接だけで戦うことになる。
const GUN_PREFIX := "gun:"
# キャラクター選択前・ヘッドレステストなど、キャラが未確定のまま始まったマッチの既定の初期武器。
# grant_start_weapon()がキャラクターの初期武器へ差し替える。
const DEFAULT_START_GUN := 0
var start_guns := [DEFAULT_START_GUN,DEFAULT_START_GUN]
static func gun_token(id: int) -> String:
	return GUN_PREFIX + str(id)
static func is_gun(entry) -> bool:
	return typeof(entry) == TYPE_STRING and str(entry).begins_with(GUN_PREFIX)
static func gun_id(entry) -> int:
	return int(str(entry).substr(GUN_PREFIX.length()))
static func is_relic(entry) -> bool:
	return Items.is_relic(entry)
static func relic_id(entry) -> int:
	return Items.relic_id(entry)
# Idempotent migration keeps equipment and positions attached to the same object.
# Called explicitly during the staged inventory rollout, not on legacy fixtures.
func migrate_relic_instances(i: int) -> void:
	var build: Dictionary = builds[i]
	var serial: int = build.get("next_item_serial",0)
	for entry in build.owned.duplicate():
		if typeof(entry) != TYPE_INT: continue
		var token := Items.relic_token(entry,serial)
		while token in build.owned:
			serial += 1
			token = Items.relic_token(entry,serial)
		serial += 1
		build.owned[build.owned.find(entry)] = token
		if entry in build.equipped: build.equipped[build.equipped.find(entry)] = token
		if build.positions.has(entry):
			build.positions[token] = build.positions[entry]
			build.positions.erase(entry)
	build["next_item_serial"] = serial
# 所持庫・装備に入りうる要素の形状。武器かレリックかで参照する形状表が変わるだけで、
# fits()/occupied_cells()/auto_place()の当たり判定そのものは共通のまま。
static func shape_of(entry) -> Array:
	return WeaponShapes.shape(gun_id(entry)) if is_gun(entry) else RelicShapes.shape(relic_id(entry))
func _new_build() -> Dictionary:
	return {"owned":[],"equipped":[],"positions":{},"mods":{},"next_item_serial":0}
func _init(value: int = 1) -> void:
	seed_value = value
	generator = Generator.new(value)
	builds = [_new_build(),_new_build()]
	for i in range(2): builds[i].owned.append(gun_token(start_guns[i]))
	previous = builds.duplicate(true)
	generate_rewards()
# P8z：キャラクター選択で確定した初期武器へ差し替える。main.tscnの_ready()がnew_match()を先に
# 走らせてしまう（キャラはその後に適用される）ため、既定の初期武器しか持っていない＝まだ何も
# 動かしていない状態のときだけ差し替える。start_gunsに覚えておくのは、3本先取でマッチが終わって
# ビルドが作り直されたあとも同じ初期武器から始めるため。
func grant_start_weapon(i: int, gun: int) -> void:
	if i not in [0,1] or not Weapons.supported(gun): return
	start_guns[i] = gun
	if builds[i].owned == [gun_token(DEFAULT_START_GUN)] and builds[i].equipped.is_empty():
		builds[i].owned = [gun_token(gun)]
func capacity() -> int:
	var size := grid_size()
	return size.x * size.y
# P8x グリッド拡張基盤：容量モデルをグリッドの面積そのものに統合した（P8時点の「個数上限は
# 変更しない」という設計判断を撤回）。capacity()は「グリッドの総マス数」を返す補助関数に
# なり、着脱可否そのものはplace()/toggle()/claim()がfits()/auto_place()（実際にその形状が
# 収まる空きマスがあるか）だけで判定する。個数がいくつであっても、装備中のものの形状の合計
# 占有マスがグリッドに収まる限り装備できる——強いレリック・強い武器ほど複数マスを取るぶん、
# 結果的に「数」を圧迫する。段階別マス数はP8時点の仮値をそのまま流用（要playtest調整、
# claude/backpack-inventory-idea.md「段階1=3×2〜段階5=4×4程度」の叩き台）。
const GRID_SIZES := [Vector2i(3,2),Vector2i(4,2),Vector2i(4,3),Vector2i(4,4),Vector2i(4,4)]
func grid_size() -> Vector2i:
	return GRID_SIZES[stage-1]
# 現在装備中のもの（武器・レリック）が占有しているマスを {Vector2i(セル): 要素} で返す。
# position未記録の装備品は無視する——place()/toggle()/claim()を経由して装備したものは必ず
# positionsに記録されるため、この経路を通らずにbuilds[i]を直接書き換えるコード（テスト等）
# だけが対象になる。
func occupied_cells(i: int, exclude_id = -1) -> Dictionary:
	var cells := {}
	var positions: Dictionary = builds[i].get("positions",{})
	for id in positions:
		# Weapon tokens and relic IDs have different types; Godot rejects String == int.
		if (typeof(id) == typeof(exclude_id) and id == exclude_id) or id not in builds[i].equipped: continue
		for offset in shape_of(id): cells[positions[id]+offset] = id
	return cells
# idの形状をanchorへ置いた場合に、全マスがグリッド範囲内かつ空いているか。exclude_idは「すでに
# 置いてある自分自身」を一時的に除外するためのもの（移動時の自己衝突を避ける）。
func fits(i: int, id, anchor: Vector2i, exclude_id = -1) -> bool:
	var size := grid_size()
	var cells := occupied_cells(i,exclude_id)
	for offset in shape_of(id):
		var cell: Vector2i = anchor+offset
		if cell.x < 0 or cell.y < 0 or cell.x >= size.x or cell.y >= size.y: return false
		if cells.has(cell): return false
	return true
# 読み順（左上→右下）で最初に空いている配置先を返す。CPU準備の自動配置に使う。置き場がなければ
# Vector2i(-1,-1)——P8xではこれがそのまま「装備できない（グリッドに収まらない）」の判定にもなる
# （_equip_if_fits()参照）。P8yで人間の操作経路からは切り離した。
func auto_place(i: int, id) -> Vector2i:
	var size := grid_size()
	for y in range(size.y):
		for x in range(size.x):
			var anchor := Vector2i(x,y)
			if fits(i,id,anchor): return anchor
	return Vector2i(-1,-1)
# ドラッグ＆ドロップなど、置き場所を明示的に指定する経路。既装備品の移動にも使う。P8xにより
# 着脱可否はfits()（実際にその位置へ収まるか）だけで決まる——個数上限は撤廃済み。
func place(i: int, id, anchor: Vector2i) -> bool:
	if ready[i] or id not in builds[i].owned: return false
	var already: bool = id in builds[i].equipped
	if not fits(i,id,anchor,id if already else -1): return false
	if not already: builds[i].equipped.append(id)
	if not builds[i].has("positions"): builds[i]["positions"] = {}
	builds[i].positions[id] = anchor
	return true
# P8z：グリッドに置いてある武器のidを、読み順（上の行から、同じ行なら左から）で返す。これが
# そのラウンドの携行武器そのものになり、player.apply_build()のinventoryの並び＝数字キー1〜8と
# HUDのスロット順にもなる。「主力」という概念の置き換え先。
func carried_guns(i: int) -> Array:
	var positions: Dictionary = builds[i].get("positions",{})
	# 読み順のキー（y優先→x）を作って並べ替える。グリッドの横幅は最大4なので y*100+x で衝突しない。
	var order: Array = []
	for entry in builds[i].equipped:
		if not is_gun(entry) or not positions.has(entry): continue
		var pos: Vector2i = positions[entry]
		order.append([pos.y*100+pos.x, gun_id(entry)])
	order.sort_custom(func(a,b): return a[0] < b[0])
	var result: Array = []
	for pair in order: result.append(pair[1])
	return result
func equipped_relics(i: int) -> Array:
	return Items.relic_ids(builds[i].equipped)
func generate_rewards() -> void:
	claimed_candidates = [[],[]]
	var base: Array = generator.shuffled(Relics.SUPPORTED).slice(0,3)
	for i in range(2): rewards[i] = generator.candidates(base,Items.relic_ids(builds[i].owned)) + mod_candidates(i)
# P5: "レリック取得／主力改造" — when a carried weapon has unused modification branches, offer
# them as extra reward candidates alongside the usual relics (not in place of them; a candidate
# pool that includes zero mod tokens falls back to relics only, matching "対応武器がない場合は
# 取得可能な報酬を提示する"). Represented as "mod:<weapon_id>:<key>" tokens so the existing
# rewards[]/owned[] arrays don't need a parallel structure.
# P8z：判定の起点が「主力」から「グリッドに置いている武器」へ変わった。複数丁を携行していれば
# その全部が対象になるので報酬候補が長くなりうる——実プレイで多すぎるようなら絞る（playtest）。
func mod_candidates(i: int) -> Array:
	var result: Array = []
	for main_id in carried_guns(i):
		if not Weapons.moddable(main_id) or builds[i].get("mods",{}).has(main_id): continue
		for mod in Weapons.mods_for(main_id): result.append(Weapons.mod_token(main_id,mod.key))
	return result
func reason(i: int, id) -> String:
	if i not in [0,1]: return "無効"
	if typeof(id) == TYPE_STRING and not is_gun(id): return mod_reason(i,id)
	if is_gun(id):
		if not Weapons.supported(gun_id(id)): return "無効"
	elif not Relics.supported(id): return "無効"
	if ready[i]: return "準備完了"
	if remaining[i] <= 0: return "報酬取得済み"
	if id in claimed_candidates[i]: return "この候補は取得済み"
	if is_gun(id) and id in builds[i].owned: return "所持済み"
	if is_relic(id) and not Relics.stackable(relic_id(id)) and relic_id(id) in Items.relic_ids(builds[i].owned): return "所持済み"
	if builds[i].owned.size() >= 8: return "所持庫8個が満杯：先に破棄"
	if id not in rewards[i] and id != temporary[i]: return "候補外"
	return ""
# A mod token can go stale mid-preparation if the player takes the weapon it targets off the
# grid — "携行していない" catches that rather than leaving a permanently-unclaimable candidate
# in the pool. See confirm()'s reason()-based gate below, which relies on this to avoid
# stalling on a token that can no longer be claimed. (P8z: 旧「現在の主力ではない」。)
func mod_reason(i: int, token: String) -> String:
	if ready[i]: return "準備完了"
	if remaining[i] <= 0: return "報酬取得済み"
	var parsed := Weapons.parse_mod_token(token)
	if parsed.is_empty(): return "無効"
	if gun_token(parsed.weapon_id) not in builds[i].equipped: return "携行していない"
	if builds[i].get("mods",{}).has(parsed.weapon_id): return "改造済み"
	if token not in rewards[i]: return "候補外"
	return ""
func claim(i: int, id) -> bool:
	if reason(i,id) != "": return false
	if typeof(id) == TYPE_STRING and not is_gun(id):
		var parsed := Weapons.parse_mod_token(id)
		if not builds[i].has("mods"): builds[i]["mods"] = {}
		# 改造は武器インスタンス（id）へ紐づく。owned/equipped には触れないため、所持庫8個
		# 枠は消費しない。携行をやめても既存の改造は消えず、単に対象外になるだけ
		# （「旧武器の改造は移転しない」）。
		builds[i].mods[parsed.weapon_id] = parsed.mod_key
	else:
		# P8y 取得と配置の分離：報酬で取得したものは所持庫（owned）に入るだけで、装備はしない。
		# どのマスへ置くかはプレイヤーが準備画面でドラッグして決める（place()）。
		if is_relic(id):
			var serial: int = builds[i].get("next_item_serial",0)
			var token := Items.relic_token(relic_id(id),serial)
			while token in builds[i].owned:
				serial += 1
				token = Items.relic_token(relic_id(id),serial)
			builds[i].owned.append(token)
			builds[i]["next_item_serial"] = serial+1
		else: builds[i].owned.append(id)
	claimed_candidates[i].append(id)
	remaining[i] -= 1
	if not initial: reward_counts[i] += 1
	return true
# 「収まるなら装備する」自動配置。P8xでグリッドの空きマスが実際の制約になったため、旧来の
# 「置き場がなくても個数上限内なら装備は成立する」という抜け道は廃止した——装備が成立する＝
# 実際にグリッドへ置ける、という一本の基準に統一する。P8yで人間の操作経路（claim()の即時装備）
# からは切り離したため、現在ここを通るのはtoggle()の装備側——実質auto_prepare()＝CPUだけである。
# 人間はplace()でマスを指定して置く。
func _equip_if_fits(i: int, id) -> bool:
	var anchor := auto_place(i,id)
	if anchor.x < 0: return false
	builds[i].equipped.append(id)
	if not builds[i].has("positions"): builds[i]["positions"] = {}
	builds[i].positions[id] = anchor
	return true
func toggle(i: int, id) -> bool:
	if ready[i] or id not in builds[i].owned: return false
	if id in builds[i].equipped:
		builds[i].equipped.erase(id)
		builds[i].get("positions",{}).erase(id)
	elif not _equip_if_fits(i,id): return false
	return true
func discard(i: int, id) -> bool:
	if ready[i] or id not in builds[i].owned: return false
	builds[i].equipped.erase(id)
	builds[i].get("positions",{}).erase(id)
	builds[i].owned.erase(id)
	return true
# P8z：主力の指定が要らなくなったため、準備完了のゲートは「取れる報酬を取り切ったか」だけに
# なった。武器を1丁も置いていない（丸腰の）プレイヤーもそのままラウンドを開始できる——置くか
# 置かないかはプレイヤーの判断で、システムが強制するものではない。
func confirm(i: int) -> bool:
	if ready[i]: return false
	# reason(i,id)=="" means "still actionable" for either type of candidate — claimed relics
	# report "所持済み" and a mod token that's gone stale (weapon no longer carried) reports
	# "携行していない", so both correctly stop blocking confirm() once resolved either way.
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
		builds = [_new_build(),_new_build()]
		for i in range(2): builds[i].owned.append(gun_token(start_guns[i]))
		previous = builds.duplicate(true)
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
		# P8z：ラウンド中にフィールドで拾った武器は所持庫へ入る（グリッドのどこへ置くか、
		# そもそも置くかは次の準備画面でのプレイヤーの判断）。所持庫が8個で満杯なら入らない
		# ——先に何かを破棄しておく必要がある。旧実装の「持っていた武器＝次の主力候補」という
		# 自動確定はここで廃止した。
		for w in players[i].inventory:
			var token := gun_token(int(w.id))
			if token not in builds[i].owned and builds[i].owned.size() < 8: builds[i].owned.append(token)
		temporary[i] = players[i].temporary_relic
	generate_rewards()
