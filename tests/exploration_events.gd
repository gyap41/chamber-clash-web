extends SceneTree
# Event rooms and gold (docs/planning/FLOOR_EXPANSION_PLAN.md stage 3) on real story floors.
const Events = preload("res://scripts/game/exploration_events.gd")
const Coins = preload("res://scripts/game/exploration_coins.gd")
const Weapons = preload("res://scripts/catalog/weapon_catalog.gd")
var game
func _initialize() -> void:
	call_deferred("run")
func room_of(role: String) -> String:
	return game.floor_data.rooms.keys().filter(func(id): return game.floor_data.rooms[id].role == role)[0]
func enter(id: String) -> void:
	assert(game.move_to_room(id,game.room_data(id).doors[0].arrival),"Could not enter "+id)
func kill_all() -> void:
	for actor in game.players.slice(1):
		actor.state.inv = 0
		actor.hurt(1000)
	game._physics_process(.016)
func stand(point: Vector2) -> void:
	game.players[0].state.pos = point
	game.players[0].sync_visual()
func press_f() -> bool:
	game.door_armed = true
	return Events.use(game)
func run() -> void:
	game = load("res://scenes/game/exploration.tscn").instantiate()
	game.random_floor = true
	game.authored_campaign = true
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	game.set_pause_reason("focus",false)
	for seed_value in [1,4]:
		game.start_exploration(seed_value)
		assert(game.floor_data.errors.is_empty())
		for role in ["shop","altar","challenge"]:
			assert(game.floor_data.rooms.values().filter(func(meta): return meta.role == role).size() == 1,role)
		assert(game.floor_data.rooms[game.start_room].teleporter and game.exploration.room_state(game.start_room).get("teleporter") != null)
		var inventory = game.exploration.inventory
		assert(inventory.gold[0] == 0)
		# Gold: every defeated ordinary enemy drops its value where it fell; walking over it takes it.
		var normal: String = game.floor_data.rooms.keys().filter(func(id): return game.floor_data.rooms[id].role == "normal")[0]
		enter(normal)
		var expected := 0
		for actor in game.players.slice(1): expected += Coins.value(actor.spec.id)
		assert(expected > 0)
		kill_all()
		assert(game.exploration.encounter_status == "cleared")
		var coins: Array = Coins.entries(game)
		assert(coins.reduce(func(total, coin): return total+coin.value,0) == expected and game.coin_nodes.size() == coins.size())
		for coin in coins.duplicate():
			stand(coin.pos)
			for frame in range(30): game._physics_process(.016) # Coins land (0.35 s hop) before they can be taken.
		assert(inventory.gold[0] == expected and Coins.entries(game).is_empty(),"All dropped gold collected")
		assert(game.fx.effects.any(func(effect): return effect.kind == "text"),"Pickup shows the gold gained")
		# Shop: priced stock; refused without money (nothing charged), bought with it, and sold items stay sold.
		var shop := room_of("shop")
		enter(shop)
		var stock: Array = game.exploration.room_state(shop).shop
		assert(stock.size() == 5 and stock.filter(func(item): return item.kind in ["weapon","relic"]).size() == 3)
		var weapon: Dictionary = stock.filter(func(item): return item.kind == "weapon")[0]
		inventory.gold[0] = weapon.price-1
		stand(weapon.pos)
		assert(press_f() and not weapon.sold and inventory.gold[0] == weapon.price-1)
		inventory.gold[0] = weapon.price+5
		assert(press_f() and weapon.sold and inventory.gold[0] == 5)
		assert(not game.fx.particles.is_empty(),"Purchase burst")
		# Effects hold still while the game is paused and resume afterwards.
		var ages: Array = game.fx.particles.map(func(particle): return particle.t)
		game.set_pause_reason("menu",true)
		for frame in range(5): game._physics_process(.016)
		assert(game.fx.particles.map(func(particle): return particle.t) == ages,"Effects freeze while paused")
		game.set_pause_reason("menu",false)
		game._physics_process(.016)
		assert(game.fx.particles.is_empty() or game.fx.particles[0].t > ages[0])
		assert(game.exploration.collected_loot.has(weapon.id),"Bought weapon went to the reserve")
		var sold_nodes: int = game.event_nodes.size()
		enter(game.start_room)
		enter(shop)
		assert(weapon.sold and game.event_nodes.size() == sold_nodes,"Sold stock stays sold on revisit")
		# Teleporter: from the shop back to the entrance, arriving beside the pad.
		assert(game.start_room in Events.destinations(game) and shop in Events.destinations(game))
		assert(game.open_map(true) and game.floor_map.teleport_targets == [game.start_room])
		assert(game.floor_map.choose(0) and game.floor_map == null and game.exploration.room_id == game.start_room)
		var pad: Vector2 = game.exploration.room_state(game.start_room).teleporter
		assert(game.players[0].state.pos.distance_to(pad) <= 70)
		assert(game.fx.effects.any(func(effect): return effect.kind == "pillar") and game.fx.flash_life > 0,"Arrival pillar and flash")
		# Altar: needs HP 2 or more, costs 1 HP once, and raises a relic chest.
		var altar := room_of("altar")
		enter(altar)
		var offering: Dictionary = game.exploration.room_state(altar).altar
		stand(offering.pos)
		game.players[0].state.hp = 1.0
		assert(press_f() and not offering.used and game.players[0].state.hp == 1.0)
		game.players[0].state.hp = 4.0
		assert(press_f() and offering.used and game.players[0].state.hp == 3.0)
		var gift: Dictionary = game.Reward.current(game)
		assert(gift.source == "altar" and gift.kind == "relic")
		assert(game.fx.particles.any(func(particle): return particle.has("target")),"Offering flows into the altar")
		# Challenge: optional until started; then locked doors and three waves before an A/S weapon.
		var challenge := room_of("challenge")
		enter(challenge)
		var trial: Dictionary = game.exploration.room_state(challenge).challenge
		assert(game.players.size() == 1 and trial.state == "idle" and game.exploration.encounter_status != "active")
		stand(trial.pos)
		assert(press_f() and trial.state == "active" and game.players.size() > 1)
		for wave in range(1,Events.WAVES+1):
			assert(trial.wave == wave and game.exploration.encounter_status == "active" and not game.try_enter_door())
			assert(game.fx.banner_life > 0 and game.fx_floor.effects.filter(func(effect): return effect.kind == "warning").size() >= game.players.size()-1,"Wave banner and spawn warnings")
			kill_all()
		assert(trial.state == "done" and game.exploration.encounter_status == "cleared")
		var prize: Dictionary = game.Reward.current(game)
		assert(prize.source == "challenge" and Weapons.definition(prize.item).rarity in ["A","S"])
		assert(not game.exploration.room_state(challenge).has("supplies"),"Challenge rooms give no ordinary supplies")
	print("PASS exploration_events: gold drops/collection with hop and pickup text, effects freeze while paused, shop stock/purchase/refusal/revisit, teleport, altar cost and relic, 3-wave challenge with A/S prize")
	game.queue_free()
	await process_frame
	quit()
