extends SceneTree
# P8 バックパックグリッド配置（配置基盤）。scripts/catalog/relic_shapes.gd（オフセットリスト
# 形状）・scripts/game/match_state.gd（grid_size/fits/occupied_cells/auto_place/place、および
# toggle()/claim()/discard()への位置連動）・scripts/ui/relic_grid_cell.gd・relic_tray.gdの
# ドロップ判定を検証する。P8xでcapacity()はグリッドの総マス数（面積）を返すよう再定義され、
# 着脱可否は個数ではなくfits()/auto_place()（実際にその形状が収まる空きマスがあるか）だけで
# 決まる（詳細はmatch_state.gdのcapacity()直後のコメント参照）。この変更に伴い、旧・個数上限
# 前提だったtests/build_inventory.gdのアサーションは別途書き直し済み。さらにP8yで、claim()は
# 所持庫へ入れるだけになり自動配置しなくなった（人間が装備する経路はplace()のみ。位置を自動で
# 決めるtoggle()の装備側は実質auto_prepare()＝CPU専用）。
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var MatchState = preload("res://scripts/game/match_state.gd")
	var m = MatchState.new(1)

	# --- grid_size()：段階別マス数（要playtest調整の仮値） ---
	m.stage = 1
	assert(m.grid_size() == Vector2i(3,2))
	m.stage = 3
	assert(m.grid_size() == Vector2i(4,3))
	m.stage = 5
	assert(m.grid_size() == Vector2i(4,4))
	m.stage = 1

	# --- 形状はオフセットリスト：範囲内・重なりなしのみ配置できる ---
	m.builds[0].owned = [0,4,6,2]
	assert(m.place(0,4,Vector2i(0,0))) # ライフアンプ：縦2マス (0,0)-(0,1)
	var occ: Dictionary = m.occupied_cells(0)
	assert(occ.size() == 2 and occ[Vector2i(0,0)] == 4 and occ[Vector2i(0,1)] == 4)
	assert(not m.place(0,6,Vector2i(0,0))) # (0,0)は4が占有中
	assert(6 not in m.builds[0].equipped and 6 not in m.builds[0].positions)
	assert(not m.place(0,6,Vector2i(2,0))) # ヘビーコアの横2マスがグリッド右端(x=3)へはみ出す
	assert(m.place(0,6,Vector2i(1,0))) # (1,0)-(2,0)は空いている
	occ = m.occupied_cells(0)
	assert(occ.size() == 4 and occ[Vector2i(1,0)] == 6 and occ[Vector2i(2,0)] == 6)
	# L字トロミノ（プリズムレンズ、(0,0)/(1,0)/(0,1)）：既存配置と重なる／グリッド外は失敗
	assert(not m.fits(0,2,Vector2i(0,0))) # (0,0)が4と重なる
	assert(not m.fits(0,2,Vector2i(1,1))) # (1,2)がy=2でグリッド外（3×2は y<2まで）

	# --- 移動：exclude_idで自分自身の現占有マスを除外し、同じ場所への置き直しも成功する ---
	assert(m.place(0,4,Vector2i(0,0))) # 自分自身のマスへの再配置（実質no-op）は成功する
	assert(not m.place(0,4,Vector2i(1,0))) # 移動先(1,0)-(1,1)は(1,0)が6と重なり失敗
	assert(m.builds[0].positions[4] == Vector2i(0,0)) # 失敗した移動で位置は変化しない
	assert(not m.place(0,2,Vector2i(2,0))) # L字(2,0)/(3,0)/(2,1)：(3,0)のx=3がグリッド外(3×2はx<3)
	assert(2 not in m.builds[0].equipped and not m.builds[0].positions.has(2))
	m.builds[0].equipped.clear()
	m.builds[0].positions.clear()

	# --- auto_place()：読み順（左上→右下）で最初に収まる位置を返す ---
	assert(m.place(0,0,Vector2i(0,0))) # (0,0)を1×1のidで埋める
	var anchor: Vector2i = m.auto_place(0,2) # L字は(0,0)を含む候補が(0,0)自体の占有で弾かれ、(1,0)-(2,0)-(1,1)が最初に収まる
	assert(anchor == Vector2i(1,0))
	assert(m.fits(0,2,anchor))
	assert(m.auto_place(0,2) == Vector2i(1,0)) # 何も置いていないので同じ答えを返す（副作用なし）
	m.builds[0].equipped.clear()
	m.builds[0].positions.clear()

	# --- P8x：容量は面積に統合済み。個数ではなく「グリッドに実際に収まるか」だけで着脱可否が決まる ---
	assert(m.capacity() == 6) # stage1は3×2＝6マス（旧・個数上限3は撤廃）
	m.builds[0].owned = [10,11,12,13,14,15,16]
	assert(m.place(0,10,Vector2i(0,0)) and m.place(0,11,Vector2i(1,0)) and m.place(0,12,Vector2i(2,0)))
	assert(m.builds[0].equipped.size() == 3) # 旧モデルなら個数上限（3）がここで天井だったが、今は単に3マス使っただけ
	assert(m.place(0,13,Vector2i(0,1))) # (0,1)は空いている——旧・個数上限では弾かれていたが今は成功する
	assert(m.place(0,14,Vector2i(1,1)) and m.place(0,15,Vector2i(2,1))) # 残り2マスも埋めて6/6
	assert(m.builds[0].equipped.size() == m.capacity())
	assert(not m.place(0,16,Vector2i(0,0))) # グリッドが本当に満杯：空きマスがなければ7個目でも失敗する
	assert(16 not in m.builds[0].equipped)
	assert(m.toggle(0,10)) # 1個外せば1マス空く
	assert(m.toggle(0,16) and m.builds[0].equipped.size() == m.capacity()) # 空いたマスに収まって再び満杯

	# --- toggle()の自動配置（CPU経路）、claim()は所持庫止まり（P8y）、discard()での位置解除 ---
	m.builds[0].equipped.clear()
	m.builds[0].positions.clear()
	m.builds[0].owned = [0,1]
	assert(m.toggle(0,0) and m.builds[0].positions.has(0)) # 装備側は自動配置される（auto_prepare＝CPUが使う経路）
	assert(m.toggle(0,0) and not m.builds[0].positions.has(0)) # 解除側は位置も消える
	m.rewards[0] = [5]
	m.remaining[0] = 1
	# P8y 取得と配置の分離：claim()は所持庫へ入れるだけで、装備も配置もしない。どのマスへ置くかは
	# プレイヤーがplace()（準備画面のドラッグ）で決める。
	assert(m.claim(0,5) and 5 in m.builds[0].owned)
	assert(5 not in m.builds[0].equipped and not m.builds[0].positions.has(5))
	assert(m.place(0,5,m.auto_place(0,5)) and m.builds[0].positions.has(5)) # 自分で置いて初めて装備になる
	assert(m.discard(0,5) and not m.builds[0].positions.has(5))

	# --- UIグルー：RelicGridCell／RelicTrayのドロップ判定はmatch_state.fits()/place()に委譲 ---
	var game = load("res://scenes/game/main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.new_match(3)
	assert(game.phase == "prepare")
	var prep = game.preparation
	var ms = game.match_state
	ms.builds[0].owned = [4,6]
	prep.refresh()
	var RelicGridCell = preload("res://scripts/ui/relic_grid_cell.gd")
	var RelicTray = preload("res://scripts/ui/relic_tray.gd")
	var cell := RelicGridCell.new()
	cell.game = game
	cell.player_index = 0
	cell.cell = Vector2i(0,0)
	cell.on_drop = prep.place_relic
	assert(cell._can_drop_data(Vector2.ZERO,{"relic_id":4}))
	cell._drop_data(Vector2.ZERO,{"relic_id":4})
	assert(4 in ms.builds[0].equipped and ms.builds[0].positions[4] == Vector2i(0,0))
	var cell_same_spot := RelicGridCell.new()
	cell_same_spot.game = game
	cell_same_spot.player_index = 0
	cell_same_spot.cell = Vector2i(0,0)
	cell_same_spot.on_drop = prep.place_relic
	assert(not cell_same_spot._can_drop_data(Vector2.ZERO,{"relic_id":6})) # 既に4が占有中
	var tray := RelicTray.new()
	tray.on_drop = prep.unequip_relic
	assert(tray._can_drop_data(Vector2.ZERO,{"relic_id":4}))
	tray._drop_data(Vector2.ZERO,{"relic_id":4})
	assert(4 not in ms.builds[0].equipped and not ms.builds[0].positions.has(4))
	# 単体でnew()したControlノードは一度もシーンツリーへ入っていないため、そのままでは
	# CanvasItem RID等がリークする（refresh()経由でCards配下に足された他のノードは、次回
	# refresh()冒頭のqueue_free()で回収されるので対象外）。ここで確保した3つは明示的にfree()する。
	cell.free()
	cell_same_spot.free()
	tray.free()
	# refresh()はグリッド・控えを含めて例外なく再構築できる（スモーク：装備0〜3個食い違う状態でも）
	ms.builds[0].owned = [0,1,2,3,4,5,6,10,11,12,13,14]
	for id in [0,1,4]: ms.place(0,id,ms.auto_place(0,id))
	prep.refresh()
	print("PASS: relic grid shapes/occupancy/fits, auto-place reading order, area-based capacity ceiling (P8x), claim is storage-only (P8y), toggle/place/discard position bookkeeping, grid-cell/tray drop delegation")
	game.queue_free()
	quit()
