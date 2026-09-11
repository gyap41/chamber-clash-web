extends RefCounted
const Shop = preload("res://scripts/catalog/shop_catalog.gd")
const WIN_TARGET := Shop.WIN_TARGET
var gold := [Shop.INITIAL_GOLD,Shop.INITIAL_GOLD]
var products: Array = [[],[]]
var refreshed := [false,false]
var expansion_bought := [false,false]
var next_card_id := 0
var ended := false
const Expansions = preload("res://scripts/catalog/bag_expansions.gd")
const Generator = preload("res://scripts/game/reward_generator.gd")
const Weapons = preload("res://scripts/catalog/weapon_catalog.gd")
const Relics = preload("res://scripts/catalog/relic_catalog.gd")
const BuildGrid = preload("res://scripts/game/build_grid.gd")
const Items = preload("res://scripts/game/item_identity.gd")
var generator
var seed_value: int
var scores := [0,0]
var stage := 1
var builds: Array = []
var previous: Array = []
var rewards: Array = [[],[]]
var ready := [false,false]
var purchase_counts := [0,0]
var temporary := [-1,-1]
var settled := false
# P8z 装備モデルの統合：所持庫（owned）と装備（equipped/positions）は武器とレリックの共通の
# 置き場になった。新規レリックは個体トークン（旧intも移行対応）、武器は "gun:<id>" という文字列トークンで表す（報酬の改造
# トークン "mod:<id>:<key>" と同じ書き方で、既存の配列・辞書構造を作り直さずに済ませるため）。
# 「主力（build.main）」と「サイドアームの自動付与」はこのフェーズで廃止し、グリッドに置いた
# 武器がそのラウンドの携行武器になる。武器を1丁も置かなければ丸腰で、近接だけで戦うことになる。
const GUN_PREFIX := Items.GUN_PREFIX
# キャラクター選択前・ヘッドレステストなど、キャラが未確定のまま始まったマッチの既定の初期武器。
# grant_start_weapon()がキャラクターの初期武器へ差し替える。
const DEFAULT_START_GUN := 0
var start_guns := [DEFAULT_START_GUN,DEFAULT_START_GUN]
static func gun_token(id: int) -> String:
	return Items.gun_token(id)

static func is_gun(entry) -> bool:
	return Items.is_gun(entry)

static func gun_id(entry) -> int:
	return Items.gun_id(entry)

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
		if build.get("acquisitions",{}).has(entry):
			build.acquisitions[token] = build.acquisitions[entry]
			build.acquisitions.erase(entry)
	build["next_item_serial"] = serial
# 所持庫・装備に入りうる要素の形状。武器かレリックかで参照する形状表が変わるだけで、
# fits()/occupied_cells()/auto_place()の当たり判定そのものは共通のまま。
static func shape_of(entry) -> Array:
	return BuildGrid.shape_of(entry)

func _new_build() -> Dictionary:
	return {"owned":[],"equipped":[],"positions":{},"mods":{},"next_item_serial":0,"acquisitions":{},"bag_expansions":[]}
func _init(value: int = 1) -> void:
	seed_value = value
	generator = Generator.new(value)
	builds = [_new_build(),_new_build()]
	for i in range(2): _acquire(i,gun_token(start_guns[i]),"initial",0,"")
	previous = builds.duplicate(true)
	generate_rewards()
# P8z：キャラクター選択で確定した初期武器へ差し替える。main.tscnの_ready()がnew_match()を先に
# 走らせてしまう（キャラはその後に適用される）ため、既定の初期武器しか持っていない＝まだ何も
# 動かしていない状態のときだけ差し替える。start_gunsに覚えておくのは、5本先取でマッチが終わって
# ビルドが作り直されたあとも同じ初期武器から始めるため。
func grant_start_weapon(i: int, gun: int) -> void:
	if i not in [0,1] or not Weapons.supported(gun): return
	start_guns[i] = gun
	if builds[i].owned == [gun_token(DEFAULT_START_GUN)] and builds[i].equipped.is_empty():
		builds[i].owned = []
		builds[i].acquisitions = {}
		_acquire(i,gun_token(gun),"initial",0,"")
# Paid patches persist independently of preparation number; one purchase per preparation.
# The canvas limit and usable region are separate. No full 36-cell unlock.
const RESERVE_CAPACITY := BuildGrid.RESERVE_CAPACITY
const MAX_CARRIED_WEAPONS := BuildGrid.MAX_CARRIED_WEAPONS
const MAX_GRID_SIZE := BuildGrid.MAX_GRID_SIZE
func grid_size() -> Vector2i:
	return MAX_GRID_SIZE
func usable_cells(i: int = 0) -> Dictionary:
	return BuildGrid.usable_cells(builds[i])

func capacity(i: int = 0) -> int:
	return usable_cells(i).size()
func expansion_pending(i: int) -> bool:
	return i in [0,1] and not ended and not expansion_bought[i] and capacity(i) <= 20
func expansion_purchase_reason(i: int, shape: String) -> String:
	if i not in [0,1] or not Expansions.SHAPES.has(shape): return "無効な拡張"
	if ready[i] or ended: return "準備完了"
	if expansion_bought[i]: return "この準備では購入済み"
	if capacity(i)+Expansions.SHAPES[shape].size() > BuildGrid.MAX_AREA: return "上限24マス（残り%d）" % (BuildGrid.MAX_AREA-capacity(i))
	if gold[i] < Expansions.SHAPES[shape].size(): return "資金不足（必要%dG）" % Expansions.SHAPES[shape].size()
	return ""
func expansion_offer_reason(i: int, shape: String) -> String:
	var reason := expansion_purchase_reason(i,shape)
	if not reason.is_empty(): return reason
	for y in range(MAX_GRID_SIZE.y):
		for x in range(MAX_GRID_SIZE.x):
			if expansion_reason(i,shape,Vector2i(x,y)).is_empty(): return ""
	return "この形を置ける場所なし"
func expansion_reason(i: int, shape: String, anchor: Vector2i) -> String:
	var reason := expansion_purchase_reason(i,shape)
	if not reason.is_empty(): return reason
	var usable := usable_cells(i)
	var connected := false
	for offset in Expansions.SHAPES[shape]:
		var cell: Vector2i = anchor+offset
		if cell.x < 0 or cell.y < 0 or cell.x >= MAX_GRID_SIZE.x or cell.y >= MAX_GRID_SIZE.y: return "グリッドの外"
		if usable.has(cell): return "開放済みマスと重複"
		for direction in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			if usable.has(cell+direction): connected = true
	return "" if connected else "バッグに辺で接続してください"
func place_expansion(i: int, shape: String, anchor: Vector2i) -> bool:
	if not expansion_reason(i,shape,anchor).is_empty(): return false
	gold[i] -= Expansions.SHAPES[shape].size()
	expansion_bought[i] = true
	if not builds[i].has("bag_expansions"): builds[i]["bag_expansions"] = []
	builds[i].bag_expansions.append({"shape":shape,"anchor":anchor})
	return true
func auto_expand(i: int) -> bool:
	if not expansion_pending(i): return false
	for shape in Expansions.SHAPES:
		for y in range(MAX_GRID_SIZE.y):
			for x in range(MAX_GRID_SIZE.x):
				if place_expansion(i,shape,Vector2i(x,y)): return true
	return false
func reserve_items(i: int) -> Array:
	return builds[i].owned.filter(func(entry): return entry not in builds[i].equipped)
func reserve_full(i: int) -> bool:
	return reserve_items(i).size() >= RESERVE_CAPACITY
# Field weapons enter the persistent reserve immediately, never the current loadout.
func field_weapon_reason(i: int, id: int) -> String:
	if i not in [0,1] or not Weapons.distributable(id): return "取得できない武器"
	if ended or settled or not ready.all(func(value): return value): return "戦闘中のみ取得可能"
	if gun_token(id) in builds[i].owned: return "所持済み（弾薬補給は弾薬箱）"
	if reserve_full(i): return "控え8個が満杯"
	return ""
func store_field_weapon(i: int, id: int) -> bool:
	if not field_weapon_reason(i,id).is_empty(): return false
	_acquire(i,gun_token(id),"field",0,"")
	return true
# Atomic CPU rearrangement: a greedy packing must not overflow reserve or lose items.
func arrange(i: int, order: Array) -> bool:
	if ready[i] or ended: return false
	var equipped: Array = builds[i].equipped.duplicate()
	var positions: Dictionary = builds[i].positions.duplicate()
	builds[i].equipped = []
	builds[i].positions = {}
	for entry in order:
		if entry in builds[i].owned and entry not in builds[i].equipped: _equip_if_fits(i,entry)
	if reserve_items(i).size() > RESERVE_CAPACITY:
		builds[i].equipped = equipped
		builds[i].positions = positions
		return false
	return true
# 現在装備中のもの（武器・レリック）が占有しているマスを {Vector2i(セル): 要素} で返す。
# position未記録の装備品は無視する——place()/toggle()/claim()を経由して装備したものは必ず
# positionsに記録されるため、この経路を通らずにbuilds[i]を直接書き換えるコード（テスト等）
# だけが対象になる。
func occupied_cells(i: int, exclude_id = -1) -> Dictionary:
	return BuildGrid.occupied_cells(builds[i],exclude_id)

# idの形状をanchorへ置いた場合に、全マスがグリッド範囲内かつ空いているか。exclude_idは「すでに
# 置いてある自分自身」を一時的に除外するためのもの（移動時の自己衝突を避ける）。
func fits(i: int, id, anchor: Vector2i, exclude_id = -1) -> bool:
	if is_gun(id) and id not in builds[i].equipped and carried_guns(i).size() >= MAX_CARRIED_WEAPONS: return false
	return BuildGrid.fits(id,anchor,usable_cells(i),occupied_cells(i,exclude_id))

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
	if ready[i] or ended or id not in builds[i].owned: return false
	var already: bool = id in builds[i].equipped
	if not already and is_gun(id) and carried_guns(i).size() >= MAX_CARRIED_WEAPONS: return false
	if not fits(i,id,anchor,id if already else -1): return false
	if not already: builds[i].equipped.append(id)
	if not builds[i].has("positions"): builds[i]["positions"] = {}
	builds[i].positions[id] = anchor
	return true
# P8z：グリッドに置いてある武器のidを、読み順（上の行から、同じ行なら左から）で返す。これが
# そのラウンドの携行武器そのものになり、player.apply_build()のinventoryの並び＝数字キー1〜8と
# HUDのスロット順にもなる。「主力」という概念の置き換え先。
func carried_guns(i: int) -> Array:
	return BuildGrid.carried_guns(builds[i])

func equipped_relics(i: int) -> Array:
	return Items.relic_ids(builds[i].equipped)
func _base_products() -> Array:
	var result: Array = []
	for slot in range(2):
		var roll: int = generator.rng.randi_range(0,99)
		var rarity: String
		if stage < 3: rarity = "C" if roll < 35 else ("B" if roll < 75 else "A")
		else: rarity = "C" if roll < 25 else ("B" if roll < 60 else ("A" if roll < 85 else "S"))
		var pool: Array = Weapons.rarity_pool(rarity)
		result.append(gun_token(pool[generator.rng.randi_range(0,pool.size()-1)]))
	for slot in range(3): result.append(Relics.SUPPORTED[generator.rng.randi_range(0,Relics.SUPPORTED.size()-1)])
	return result
func _card(entry) -> Dictionary:
	var result := {"id":"card:%d" % next_card_id,"entry":entry,"price":Shop.price(entry),"sold":false}
	next_card_id += 1
	return result
func _set_products(i: int, base: Array) -> void:
	products[i] = []
	for entry in base: products[i].append(_card(entry))
	_sync_rewards(i)
	sync_mod_product(i)
func _sync_rewards(i: int) -> void:
	rewards[i] = products[i].map(func(card): return card.entry)
func generate_rewards() -> void:
	var base := _base_products()
	for i in range(2): _set_products(i,base)
func sync_mod_product(i: int) -> void:
	if ready[i] or ended: return
	# Once offered, retain even an unavailable mod: moving equipment is not a free reroll.
	var cards: Array = products[i].filter(func(card): return str(card.entry).begins_with("mod:"))
	if not cards.is_empty(): return
	var candidates := mod_candidates(i)
	if not candidates.is_empty(): products[i].append(_card(candidates[generator.rng.randi_range(0,candidates.size()-1)]))
	_sync_rewards(i)
func refresh_shop(i: int) -> bool:
	if i not in [0,1] or ready[i] or ended or refreshed[i] or gold[i] < Shop.REFRESH_PRICE: return false
	gold[i] -= Shop.REFRESH_PRICE
	refreshed[i] = true
	_set_products(i,_base_products())
	return true
func product(i: int, card_id: String) -> Dictionary:
	if i not in [0,1]: return {}
	for card in products[i]:
		if card.id == card_id: return card
	return {}
func mod_candidates(i: int) -> Array:
	var result: Array = []
	for main_id in carried_guns(i):
		if not Weapons.moddable(main_id) or builds[i].get("mods",{}).has(main_id): continue
		for mod in Weapons.mods_for(main_id): result.append(Weapons.mod_token(main_id,mod.key))
	return result
func acquisition_reason(i: int, entry) -> String:
	if i not in [0,1]: return "無効"
	if ready[i] or ended: return "準備完了"
	if str(entry).begins_with("mod:"): return mod_reason(i,entry)
	if is_gun(entry):
		if not Weapons.supported(gun_id(entry)): return "無効"
		if entry in builds[i].owned: return "所持済み"
	elif typeof(entry) != TYPE_INT or not Relics.supported(entry): return "無効"
	elif not Relics.stackable(entry) and entry in Items.relic_ids(builds[i].owned): return "所持済み"
	if reserve_full(i): return "控え8個が満杯：先に配置または売却"
	return ""
func purchase_reason(i: int, card_id: String) -> String:
	var card := product(i,card_id)
	if card.is_empty(): return "候補外"
	if card.price < 0 or (is_gun(card.entry) and not Weapons.distributable(gun_id(card.entry))): return "非売品"
	if card.sold: return "売り切れ"
	var why := acquisition_reason(i,card.entry)
	if not why.is_empty(): return why
	if gold[i] < card.price: return "資金不足"
	return ""
func purchase(i: int, card_id: String) -> bool:
	if not purchase_reason(i,card_id).is_empty(): return false
	var card := product(i,card_id)
	# All validation precedes this synchronous transaction; no signal/await in between.
	gold[i] -= card.price
	card.sold = true
	_acquire(i,card.entry,"purchase",card.price,card.id)
	purchase_counts[i] += 1
	return true
func _acquire(i: int, entry, source: String, paid: int, card_id: String):
	var token = entry
	if str(entry).begins_with("mod:"):
		var parsed := Weapons.parse_mod_token(entry)
		if not builds[i].has("mods"): builds[i]["mods"] = {}
		builds[i].mods[parsed.weapon_id] = parsed.mod_key
	elif is_relic(entry):
		var serial: int = builds[i].get("next_item_serial",0)
		token = Items.relic_token(relic_id(entry),serial)
		while token in builds[i].owned:
			serial += 1
			token = Items.relic_token(relic_id(entry),serial)
		builds[i]["next_item_serial"] = serial+1
		builds[i].owned.append(token)
	else: builds[i].owned.append(token)
	if not builds[i].has("acquisitions"): builds[i]["acquisitions"] = {}
	builds[i].acquisitions[token] = {"source":source,"paid":paid,"card_id":card_id}
	return token
func temporary_reason(i: int) -> String:
	if i not in [0,1] or temporary[i] < 0: return "持ち帰り候補なし"
	return acquisition_reason(i,temporary[i])
func claim_temporary(i: int) -> bool:
	if not temporary_reason(i).is_empty(): return false
	_acquire(i,temporary[i],"field",0,"")
	temporary[i] = -1
	return true
# Compatibility convenience for callers selecting an entry. UI uses immutable card IDs.
func reason(i: int, entry) -> String:
	if i not in [0,1]: return "無効"
	for card in products[i]:
		if typeof(card.entry) == typeof(entry) and card.entry == entry: return purchase_reason(i,card.id)
	return "候補外"
func claim(i: int, entry) -> bool:
	if i not in [0,1]: return false
	for card in products[i]:
		if typeof(card.entry) == typeof(entry) and card.entry == entry: return purchase(i,card.id)
	return false
func mod_reason(i: int, token: String) -> String:
	if ready[i] or ended: return "準備完了"
	var parsed := Weapons.parse_mod_token(token)
	if parsed.is_empty(): return "無効"
	if gun_token(parsed.weapon_id) not in builds[i].equipped: return "携行していない"
	if builds[i].get("mods",{}).has(parsed.weapon_id): return "改造済み"
	return ""
func sale_value(i: int, entry) -> int:
	return int(builds[i].get("acquisitions",{}).get(entry,{}).get("paid",0)/2)
func sell(i: int, entry) -> bool:
	if i not in [0,1] or ready[i] or ended or entry not in builds[i].owned: return false
	var value := sale_value(i,entry)
	if not discard(i,entry): return false
	gold[i] += value
	return true
# 「収まるなら装備する」自動配置。P8xでグリッドの空きマスが実際の制約になったため、旧来の
# 「置き場がなくても個数上限内なら装備は成立する」という抜け道は廃止した——装備が成立する＝
# 実際にグリッドへ置ける、という一本の基準に統一する。P8yで人間の操作経路（claim()の即時装備）
# からは切り離したため、現在ここを通るのはtoggle()の装備側——実質auto_prepare()＝CPUだけである。
# 人間はplace()でマスを指定して置く。
func _equip_if_fits(i: int, id) -> bool:
	if is_gun(id) and carried_guns(i).size() >= MAX_CARRIED_WEAPONS: return false
	var anchor := auto_place(i,id)
	if anchor.x < 0: return false
	builds[i].equipped.append(id)
	if not builds[i].has("positions"): builds[i]["positions"] = {}
	builds[i].positions[id] = anchor
	return true
func toggle(i: int, id) -> bool:
	if ready[i] or ended or id not in builds[i].owned: return false
	if id in builds[i].equipped:
		if reserve_full(i): return false
		builds[i].equipped.erase(id)
		builds[i].get("positions",{}).erase(id)
	elif not _equip_if_fits(i,id): return false
	return true
func discard(i: int, id) -> bool:
	if ready[i] or ended or id not in builds[i].owned: return false
	builds[i].equipped.erase(id)
	builds[i].get("positions",{}).erase(id)
	builds[i].owned.erase(id)
	builds[i].get("acquisitions",{}).erase(id)
	if is_gun(id):
		builds[i].mods.erase(gun_id(id))
		for key in builds[i].get("acquisitions",{}).keys():
			if str(key).begins_with("mod:%d:" % gun_id(id)): builds[i].acquisitions.erase(key)
	return true
# Shopping and expansion are optional, including unarmed preparation.
func confirm(i: int) -> bool:
	if i not in [0,1] or ready[i] or ended: return false
	ready[i] = true
	return true
func start_round() -> void:
	previous = builds.duplicate(true)
	settled = false
func finish(winner: int, players: Array) -> void:
	if settled or ended: return
	settled = true
	if winner < 0: return
	scores[winner] += 1
	if scores.max() >= WIN_TARGET:
		ended = true
		gold = [0,0]
		products = [[],[]]
		refreshed = [false,false]
		expansion_bought = [false,false]
		next_card_id = 0
		builds = [_new_build(),_new_build()]
		for i in range(2): _acquire(i,gun_token(start_guns[i]),"initial",0,"")
		previous = builds.duplicate(true)
		rewards = [[],[]]
		temporary = [-1,-1]
		purchase_counts = [0,0]
		ready = [false,false]
		return
	stage += 1
	refreshed = [false,false]
	expansion_bought = [false,false]
	ready = [false,false]
	for i in range(2):
		# Weapons were already stored at chest acquisition, including after a draw.
		temporary[i] = players[i].temporary_relic
		gold[i] += Shop.income(stage)
	generate_rewards()
