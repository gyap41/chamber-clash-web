extends SceneTree
# P8x：容量モデルをグリッドの面積に統合したことに伴い、このテストが前提にしていた「装備6個
# ちょうどで個数上限に達する」という挙動（旧stage4の固定capacity()==6）はなくなった。面積
# ベースでは同じ6個（id2・id4が複数マス）でもグリッドに空きがある限り装備でき、グリッドが
# 本当に満杯かどうかはtests/relic_grid.gdの専用ケースで検証している。ここでは「所持庫8個の
# 上限」「入れ替え・破棄」「重複・仮装備ガード」「回復抜け防止」「主力Sの装備・ラウンド
# リセット」という、容量モデルの具体的な数値には依存しない部分を検証する。
# P8y：さらにclaim()から即時装備を外し、取得（owned入り）と配置（place()）を分離した。
# 「取っただけでは装備にならず、自分で置いて初めて装備になる」ことをclaim(0,8)の前後で確認する。
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var game = load("res://scenes/game/main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	var m = game.match_state
	m.stage = 4
	m.builds[0] = {"owned":[0,1,2,3,4,5,6,7],"equipped":[],"positions":{},"mods":{}} # P8z：mainは廃止。所持庫はレリック8個で満杯の状態を作る
	for id in [0,1,2,3,4,5]: assert(m.place(0,id,m.auto_place(0,id))) # 実際にグリッドへ置いて装備させる（占有マスを正しく記録するため）
	m.rewards[0] = [8,9,10]
	m.remaining[0] = 1
	assert(not m.claim(0,8)) # 所持庫8個で満杯：グリッドの空き（stage4は4×4=16マス、まだ7マス空き）に関係なく弾かれる
	assert(m.toggle(0,6) and 6 in m.builds[0].equipped) # グリッドに空きがあるので装備できる（旧・個数上限6ならここで弾かれていた）
	assert(m.toggle(0,6) and 6 not in m.builds[0].equipped) # 解除も通常どおり
	assert(m.builds[0].equipped.size() == 6)
	assert(m.discard(0,7) and m.claim(0,8)) # 7を破棄して空けた枠に8を獲得
	var acquired = m.builds[0].owned.back()
	assert(m.relic_id(acquired) == 8 and acquired not in m.builds[0].equipped) # P8y：claim()は所持庫へ入れるだけ。グリッドに空きがあっても自動では装備されない
	assert(m.place(0,acquired,m.auto_place(0,acquired)) and acquired in m.builds[0].equipped) # 自分で置いて初めて装備になる
	assert(m.toggle(0,acquired) and acquired not in m.builds[0].equipped) # 以降の検証は装備6個の状態で続けるので外しておく
	assert(m.builds[0].owned.size() == 8 and not m.claim(0,9))
	var p = game.players[0]
	p.state.hp = 3
	for n in range(8):
		p.apply_build(m.builds[0],m.capacity())
		m.toggle(0,4)
		p.apply_build(m.builds[0],m.capacity())
		m.toggle(0,4)
	assert(p.state.hp == 3)
	p.apply_build(m.builds[0],m.capacity(),true)
	assert(p.state.hp == 10)
	assert(p.relics.size() == 6) # 最初にplace()した6個だけ。claim(0,8)は所持庫止まりで装備には数えられない
	# 仮装備ガード（player.gdのrelic_capacity到達）は容量モデルの数値そのものとは独立した
	# ロジックなので、ここではcapacity引数にちょうど今の装備数を渡して「満杯」の境界を作る
	# （play_feedback.gdで使われている手法と同じ）。
	p.apply_build(m.builds[0],p.relics.size(),true)
	assert(not p.acquire_temporary(9)) # ちょうど満杯なので仮装備できない
	p.apply_build(m.builds[0],p.relics.size()+1,true)
	assert(p.acquire_temporary(9) and not p.acquire_temporary(10)) # 1枠空けば1個だけ仮装備できる。仮装備は1ラウンド1個まで
	assert(p.temporary_relic == 9 and p.relics.size() == p.relic_capacity)
	# Stored (unequipped) IDs cannot be acquired again on the field.
	p.temporary_relic = -1
	assert(not p.acquire_temporary(3))
	game.new_match(5)
	for i in range(2): game.preparation.auto_prepare(i)
	game.launch_round()
	p.add_gun(8)
	p.weapon().clip = 0
	p.weapon().mode = 1
	p.state.hp = 1
	p.state.pulses = 0
	p.state.shield = 10
	game.players[1].state.hp = 0
	game._physics_process(.01)
	game.reset_round()
	# P8z：ラウンド中に拾った武器は所持庫へ入る。主力の指定はなくなったので、次のラウンドで使う
	# には自分でグリッドへ置く。ここでは一度すべて外してから8だけを置き、携行1丁の状態を作る。
	var gun8: String = game.match_state.gun_token(8)
	assert(gun8 in game.match_state.builds[0].owned)
	for entry in game.match_state.builds[0].equipped.duplicate(): game.match_state.toggle(0,entry)
	assert(game.match_state.place(0,gun8,game.match_state.auto_place(0,gun8)))
	for i in range(2):
		for id in game.match_state.rewards[i]:
			if game.match_state.remaining[i] > 0: game.match_state.claim(i,id)
		assert(game.match_state.confirm(i))
	game.launch_round()
	assert(p.weapon().id == 8 and p.weapon().clip == p.definition().mag and p.weapon().mode == 0)
	assert(p.state.hp == p.state.max_hp and p.state.pulses == p.initial_pulses and p.state.shield == 0)
	assert(p.inventory.size() == 1) # 置いた8の1丁だけ（サイドアームの自動付与は廃止）
	print("PASS: 8 inventory, area-based equip (P8x), claim-does-not-place (P8y), swap/discard, duplicate/temp guards, no healing exploit, S main/reset")
	game.queue_free()
	quit()
