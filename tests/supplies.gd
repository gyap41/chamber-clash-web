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
	assert(s.acquire(0,item) and p.weapon().id == 4)
	assert(not s.acquire(1,item) and q.inventory.size() == 2)
	assert(p.inventory.size() == 3)
	s.step(.01)
	assert(item not in s.items)
	# Identical weapon refills the matching slot, not the active weapon.
	p.equip_slot(0)
	p.inventory[2].clip = 2
	p.inventory[2].reserve = 0
	item = s.put_item("weapon",4,Vector2(100,100))
	mature(item)
	assert(s.acquire(0,item))
	assert(p.state.gun == 0 and p.inventory[2].clip == 2 and p.inventory[2].reserve == 18)
	s.step(.01)
	p.inventory[2].reserve = 29
	item = s.put_item("weapon",4,Vector2(100,100))
	mature(item)
	assert(s.acquire(0,item) and p.inventory[2].reserve == 30)
	s.step(.01)
	item = s.put_item("weapon",4,Vector2(100,100))
	mature(item)
	assert(not s.acquire(0,item) and not item.used)
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
	# Full inventory never auto-replaces; G replaces only the selected slot.
	assert(p.add_gun(18))
	p.weapon().clip = 2
	p.weapon().mode = 1
	p.start_reload()
	var untouched: Dictionary = p.inventory[0].duplicate()
	item = s.put_item("weapon",19,Vector2(100,100))
	mature(item)
	assert(not s.acquire(0,item) and p.weapon().id == 18)
	var key := InputEventKey.new()
	key.pressed = true
	key.keycode = KEY_G
	game._unhandled_key_input(key)
	assert(item.used and p.weapon().id == 19 and p.inventory.size() == 4)
	assert(p.inventory[0] == untouched and p.weapon().mode == 0 and p.weapon().clip == 6)
	assert(p.state.reload == 0 and p.state.reload_slot == -1 and p.state.shot >= .15)
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
	assert(item.used and q.weapon().id == 6)
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
	print("PASS: pickup delay, touch/range, duplicate/refill caps, ammo, full slots/G/H exchange, single owner, pause/result/reset, schedules, expiry, editable spawns")
	game.queue_free()
	quit()
