extends SceneTree
# P7 宝箱演出：武器・レリックのフィールド補給は「宝箱」化し、触れるだけでは入手できない。
# interact()（G/H）で開封を開始したプレイヤーがinteract_radius内に留まり続けた場合のみ、
# supplies.chest_open_durationが経過するとacquire()が呼ばれて入手が確定する。開封中は
# 無敵化されない。弾薬箱（kind=="ammo"）は対象外で、従来どおり触れるだけで即時補給される。
func _initialize() -> void:
	call_deferred("run")
func launch(game) -> void:
	game.reset_round()
	preload("res://tests/helpers/battle.gd").start(game,1)
func mature(item) -> void:
	item.age = .6
func run() -> void:
	var game = load("res://scenes/game/main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	launch(game)
	var s = game.supplies
	var p = game.players[0]
	var q = game.players[1]
	s.reset()
	p.state.pos = Vector2(300,300)
	q.state.pos = Vector2(900,300)
	# 触れる（近づく）だけでは入手できない：従来の自動タッチ入手を廃止。
	var item = s.put_item("weapon",7,p.state.pos)
	mature(item)
	s.step(.5)
	assert(item.opening_player == -1 and not item.used and not ("gun:7" in game.match_state.builds[0].owned))
	# interact()で開封を開始。chest_open_duration未満ではまだ確定しない。
	s.interact(0)
	assert(item.opening_player == 0 and item.open_progress == 0.0)
	s.step(s.chest_open_duration*.5)
	assert(not item.used and item.open_progress > 0.0 and item.open_progress < s.chest_open_duration)
	# 開封中は無敵化されない：通常どおり被弾する。
	var hp_before: float = p.state.hp
	p.hurt(1.0)
	assert(is_equal_approx(p.state.hp,hp_before-1.0))
	# 残り時間が経過すると入手確定。
	s.step(s.chest_open_duration)
	assert(item not in s.items and ("gun:7" in game.match_state.builds[0].owned))
	s.reset()
	# その場（interact_radius内）を離れると開封が中断され、進捗はリセットされる。
	item = s.put_item("weapon",9,p.state.pos)
	mature(item)
	s.interact(0)
	s.step(s.chest_open_duration*.7)
	assert(item.open_progress > 0.0)
	var opened_pos: Vector2 = p.state.pos
	p.state.pos = opened_pos + Vector2(s.interact_radius+10,0)
	s.step(.01)
	assert(item.opening_player == -1 and item.open_progress == 0.0 and not item.used and not ("gun:9" in game.match_state.builds[0].owned))
	s.reset()
	# 他プレイヤーが開封中の宝箱は横取りできない（interact()は無視される）。
	p.state.pos = Vector2(300,300)
	q.state.pos = Vector2(300,300)
	item = s.put_item("weapon",10,p.state.pos)
	mature(item)
	s.interact(0)
	assert(item.opening_player == 0)
	s.interact(1)
	assert(item.opening_player == 0)
	s.reset()
	# レリック補給も同じ開封フロー（無敵化なし・その場で数秒待つ）に従う。
	p.state.pos = Vector2(300,300)
	item = s.put_item("relic",2,p.state.pos)
	mature(item)
	assert(2 not in p.relics)
	s.interact(0)
	assert(item.opening_player == 0 and not item.used)
	s.step(s.chest_open_duration*.5)
	assert(not item.used and 2 not in p.relics)
	s.step(s.chest_open_duration)
	assert(item not in s.items and 2 in p.relics)
	s.reset()
	# 弾薬箱は宝箱化の対象外：従来どおり触れるだけで即時補給される（回帰確認）。
	for w in p.inventory: w.reserve = 0
	item = s.put_item("ammo",0,p.state.pos)
	mature(item)
	s.step(.01)
	assert(item not in s.items and p.inventory[0].reserve > 0)
	s.reset()
	# P7 CPU対称化：CPU（scripts/ai/cpu_ai.gd）も人間と同じ開封待ちに従う。CpuAI.decide()を
	# 直接呼び出し、p1をCPU側（index1）として扱う（tests/cpu_ai.gdと同じ手法）。
	game.remaining = game.round_duration
	q.state.pos = Vector2(170,300)
	p.state.pos = Vector2(900,300)
	item = s.put_item("weapon",11,q.state.pos)
	mature(item)
	game.CpuAI.decide(game,q,p,1.0/60.0)
	assert(item.opening_player == 1 and item.open_progress == 0.0 and not item.used)
	s.step(s.chest_open_duration*.5)
	assert(item.open_progress > 0.0 and item.open_progress < s.chest_open_duration and not item.used)
	game.CpuAI.decide(game,q,p,1.0/60.0) # re-selecting the same target keeps opening_player == 1
	assert(item.opening_player == 1)
	s.step(s.chest_open_duration)
	assert(item not in s.items and ("gun:11" in game.match_state.builds[1].owned))
	s.reset()
	# 人間（P1）が開封中の宝箱をCPUが横取りできない。
	p.state.pos = Vector2(300,300)
	q.state.pos = Vector2(300,300)
	item = s.put_item("weapon",12,p.state.pos)
	mature(item)
	s.interact(0)
	assert(item.opening_player == 0)
	game.CpuAI.decide(game,q,p,1.0/60.0)
	assert(item.opening_player == 0) # CPUは進行中の人間の開封を奪えない
	s.step(s.chest_open_duration)
	assert(item not in s.items and ("gun:12" in game.match_state.builds[0].owned) and not ("gun:12" in game.match_state.builds[1].owned))
	s.reset()
	# 逆に、CPUが開封中の宝箱を人間がGキーで横取りできない。
	q.state.pos = Vector2(300,300)
	p.state.pos = Vector2(300,300)
	item = s.put_item("weapon",13,q.state.pos)
	mature(item)
	game.CpuAI.decide(game,q,p,1.0/60.0)
	assert(item.opening_player == 1)
	s.interact(0)
	assert(item.opening_player == 1) # 人間は進行中のCPUの開封を奪えない
	s.step(s.chest_open_duration)
	assert(item not in s.items and ("gun:13" in game.match_state.builds[1].owned) and not ("gun:13" in game.match_state.builds[0].owned))
	s.reset()
	# スポーン直後（pickup_delay未満の無敵猶予中）はCPUも開封を開始しない（interact()と同条件）。
	item = s.put_item("weapon",14,q.state.pos)
	assert(item.age < s.pickup_delay)
	game.CpuAI.decide(game,q,p,1.0/60.0)
	assert(item.opening_player == -1)
	print("PASS: weapon/relic chests require interact+wait with no invincibility, cancel on leaving range, cannot be stolen, ammo pickup unaffected, CPU follows the same chest-opening wait and cannot steal or be stolen from")
	game.queue_free()
	quit()
