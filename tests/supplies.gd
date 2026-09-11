extends SceneTree
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
	var s = game.supplies
	var p = game.players[0]
	var q = game.players[1]
	assert(s.items.is_empty())
	s.step(13)
	assert(s.elapsed == 0 and s.items.is_empty())
	launch(game)
	assert(s.items.size() == 2 and s.items.all(func(x): return x.kind == "ammo"))
	assert(s.items[0].position == Vector2(160,460))
	assert(s.put_item("weapon",4,Vector2(160,460)) == null)
	assert(s.put_item("weapon",4,Vector2(260,180)) == null)
	assert(s.put_item("weapon",4,Vector2(-10,-10)) == null)
	assert(s.put_item("weapon",99,Vector2(100,100)) == null)
	for i in range(100):
		assert(game.Weapons.definition(s.weighted_gun()).rarity != "S")
		assert(game.Weapons.definition(s.weighted_gun(true)).rarity == "S")
	var item = s.put_item("weapon",4,Vector2(100,100))
	p.state.pos = item.position
	assert(not s.acquire(0,item)) # spawn protection
	mature(item)
	var loadout: Array = p.inventory.duplicate(true)
	assert(not s.acquire(0,item)) # weapons never use the touch path
	assert(s.acquire(0,item,true) and p.inventory == loadout)
	assert("gun:4" in game.match_state.reserve_items(0) and not p.owns(4))
	assert(not s.acquire(1,item,true) and q.inventory.size() == 2)
	s.step(.01)
	assert(item not in s.items)
	# Duplicate weapons are rejected, including when carried ammo is empty.
	assert(p.add_gun(4)) # explicit combat fixture for ammunition preservation
	p.equip_slot(0)
	p.inventory[2].clip = 2
	p.inventory[2].reserve = 0
	item = s.put_item("weapon",4,Vector2(100,100))
	mature(item)
	assert(not s.acquire(0,item,true) and not item.used)
	assert(p.state.gun == 0 and p.inventory[2].clip == 2 and p.inventory[2].reserve == 0)
	s.reset()
	# Ammo box refills all reserves by ceil(stock*.4), preserving clips/mode.
	item = s.put_item("ammo",0,Vector2(100,100))
	mature(item)
	for w in p.inventory: w.reserve = 0
	assert(s.acquire(0,item))
	assert(p.inventory[0].reserve == 24 and p.inventory[1].reserve == 20 and p.inventory[2].reserve == 12)
	assert(p.inventory[2].clip == 2)
	s.step(.01)
	for w in p.inventory: w.reserve = int(game.Weapons.definition(w.id).stock)
	item = s.put_item("ammo",0,Vector2(100,100))
	mature(item)
	assert(not s.acquire(0,item) and not item.used)
	s.reset()
	# Full carried inventory still allows reserve storage; active reload/mode never change.
	for id in [2,3,5,6]: assert(p.add_gun(id))
	assert(p.add_gun(18))
	assert(p.inventory.size() == p.MAX_CARRIED_WEAPONS)
	p.weapon().clip = 2
	p.weapon().mode = 1
	p.start_reload()
	var untouched: Array = p.inventory.duplicate(true)
	var reload_before: float = p.state.reload
	var reload_slot_before: int = p.state.reload_slot
	var shot_before: float = p.state.shot
	item = s.put_item("weapon",19,Vector2(100,100))
	mature(item)
	assert(not s.acquire(0,item) and p.weapon().id == 18)
	var key := InputEventKey.new()
	key.pressed = true
	key.keycode = KEY_G
	# P7 宝箱演出：Gキー1回では即入手できず、開封が始まるだけ（無敵化はしない）。
	game._unhandled_key_input(key)
	assert(item.opening_player == 0 and not item.used and p.weapon().id == 18)
	# 開封完了まで待たずに離れると中断・進捗リセット。
	s.step(s.chest_open_duration*.5)
	assert(item.open_progress > 0.0 and not item.used)
	var opened_pos: Vector2 = p.state.pos
	p.state.pos = opened_pos + Vector2(s.interact_radius+5,0)
	s.step(.01)
	assert(item.opening_player == -1 and item.open_progress == 0.0 and not item.used)
	# 戻って開封をやり直し、chest_open_duration経過で入手が確定する。
	p.state.pos = opened_pos
	game._unhandled_key_input(key)
	assert(item.opening_player == 0)
	s.step(s.chest_open_duration)
	assert(item not in s.items and p.weapon().id == 18 and p.inventory.size() == p.MAX_CARRIED_WEAPONS)
	assert("gun:19" in game.match_state.reserve_items(0) and not p.owns(19))
	assert(p.inventory == untouched and p.weapon().mode == 1 and p.weapon().clip == 2)
	assert(p.state.reload == reload_before and p.state.reload_slot == reload_slot_before and p.state.shot == shot_before)
	s.reset()
	# Range and P2 H binding; one contested pickup cannot be awarded twice.
	q.state.pos = Vector2(100,100)
	q.add_gun(16)
	q.add_gun(18)
	item = s.put_item("weapon",6,Vector2(164,100))
	mature(item)
	assert(not s.acquire(1,item))
	key.keycode = KEY_H
	game._unhandled_key_input(key)
	assert(item.opening_player == 1 and not item.used)
	# P1がHキー中の宝箱を横取りしようとしても無視される（p(P1)も同じ宝箱のinteract_radius内）。
	key.keycode = KEY_G
	game._unhandled_key_input(key)
	assert(item.opening_player == 1)
	s.step(s.chest_open_duration)
	assert(item not in s.items and not q.owns(6) and "gun:6" in game.match_state.reserve_items(1))
	assert(not s.acquire(0,item,true))
	s.reset()
	item = s.put_item("weapon",8,Vector2(165,100))
	mature(item)
	assert(not s.acquire(1,item,true))
	# Pause freezes timers and prevents key/automatic acquisition.
	game.paused = true
	var before: float = item.age
	s.step(20)
	s.interact(1)
	assert(item.age == before and not item.used and s.elapsed == 0)
	game.paused = false
	s.reset()
	# Schedule, shared drops, one legendary event, expiry and editor markers.
	p.state.pos = Vector2(60,300)
	q.state.pos = Vector2(1060,300)
	s.step(11.9)
	assert(s.items.is_empty())
	s.step(.11)
	assert(s.items.size() == 2 and s.items.all(func(x): return x.kind == "ammo"))
	s.step(15.98)
	assert(s.items.filter(func(x): return x.kind == "weapon").is_empty())
	s.step(.02)
	var normal = s.items.filter(func(x): return x.kind == "weapon")
	assert(normal.size() == 2 and normal[0].gun == normal[1].gun)
	s.step(7.0)
	assert(s.items.filter(func(x): return x.kind == "relic").size() == 2)
	s.step(5.0)
	assert(s.legendary_warned and not s.legendary_spawned)
	s.step(5.0)
	assert(s.legendary_spawned)
	var legendary = s.items.filter(func(x): return x.position == Vector2(560,205) or x.position == Vector2(560,395))
	assert(legendary.size() == 2 and legendary[0].gun == legendary[1].gun)
	assert(game.Weapons.definition(legendary[0].gun).rarity == "S")
	s.step(.1)
	assert(s.items.filter(func(x): return x.kind == "weapon" and game.Weapons.definition(x.gun).rarity == "S").size() == 2)
	item = s.items[0]
	item.age = s.pickup_lifetime
	s.step(.01)
	assert(item not in s.items)
	game.phase = "result"
	before = s.elapsed
	s.step(10)
	assert(s.elapsed == before)
	var marker = s.get_node("Spawns/Ammo/Point1")
	marker.position = Vector2(110,220)
	launch(game)
	assert(s.elapsed == 0 and not s.legendary_spawned and s.items.size() == 2)
	assert(s.items[0].position == Vector2(110,220) and s.items[0].age == 0)
	# Automatic touch path rather than direct acquire API.
	p.state.pos = s.items[0].position
	for w in p.inventory: w.reserve = 0
	var initial = s.items[0]
	s.step(.61)
	assert(initial not in s.items)
	print("PASS: pickup delay, touch/range, duplicate rejection, ammo, full carried slots/G/H reserve storage, single owner, pause/result/reset, schedules, expiry, editable spawns")
	game.queue_free()
	quit()
