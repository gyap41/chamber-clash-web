extends RefCounted
# Event rooms (docs/planning/FLOOR_EXPANSION_PLAN.md stage 3): shop, altar, optional challenge and teleporters.
# All state lives in the room state, so revisits keep what was bought, offered or cleared. The rooms reuse
# existing room art as provisional vessels; their interactables are drawn in code until dedicated art exists.
const Reward = preload("res://scripts/game/exploration_reward.gd")
const Supplies = preload("res://scripts/game/exploration_supplies.gd")
const Loot = preload("res://scripts/game/exploration_loot.gd")
const Encounter = preload("res://scripts/game/exploration_encounter.gd")
const Shop = preload("res://scripts/catalog/shop_catalog.gd")
const Weapons = preload("res://scripts/catalog/weapon_catalog.gd")
const Relics = preload("res://scripts/catalog/relic_catalog.gd")
const Art = preload("res://scripts/ui/hud_assets.gd")
const RADIUS := 64.0
const SUPPLY_PRICES := {"heal":3,"ammo":2}
const WAVES := 3
const PAD_ARRIVAL := Vector2(0,64)

static func role(game) -> String:
	if game.floor_data.is_empty(): return ""
	return game.floor_data.rooms[game.exploration.room_id].role

static func has_teleporter(game, id: String) -> bool:
	return not game.floor_data.is_empty() and game.floor_data.rooms[id].get("teleporter",false)

# Creates this room's event state on first entry (positions are searched from the arrival point).
static func prepare(game) -> void:
	if game.floor_data.is_empty() or game.exploration.status != "active": return
	var room: Dictionary = game.exploration.room_state(game.exploration.room_id)
	var taken: Array = []
	if room.has("reward"): taken.append(room.reward.pos)
	match role(game):
		"shop":
			if not room.has("shop"): room.shop = shop_stock(game,taken)
		"altar":
			if not room.has("altar"): room.altar = {"pos":altar_point(game,taken),"used":false}
		"challenge":
			if not room.has("challenge"): room.challenge = {"pos":Reward.placement(game,taken),"state":"idle","wave":0}
	for key in ["shop","altar","challenge"]:
		if room.has(key):
			if key == "shop":
				for item in room.shop: taken.append(item.pos)
			else: taken.append(room[key].pos)
	if has_teleporter(game,game.exploration.room_id) and not room.has("teleporter"):
		room.teleporter = Reward.placement(game,taken)

static func shop_stock(game, taken: Array) -> Array:
	var progress = game.exploration
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(progress.seed_value)+":"+progress.room_id+":shop-v1")
	var known_weapons := Reward.known_items(progress,"weapon")
	var weapons: Array = Reward.weapon_pool(false).filter(func(id): return id not in known_weapons and Shop.WEAPON_PRICES[id] > 0)
	var relics: Array = Reward.relic_pool(progress).filter(func(id): return id not in Reward.known_items(progress,"relic"))
	var stock: Array = []
	for count in range(2):
		if weapons.is_empty(): break
		var item: int = weapons.pop_at(rng.randi_range(0,weapons.size()-1))
		stock.append({"kind":"weapon","item":item,"price":Shop.WEAPON_PRICES[item],"label":str(Weapons.definition(item).name)})
	if not relics.is_empty():
		var relic: int = relics[rng.randi_range(0,relics.size()-1)]
		stock.append({"kind":"relic","item":relic,"price":Shop.RELIC_PRICES[relic],"label":str(Relics.definition(relic).name)})
	stock.append({"kind":"heal","price":SUPPLY_PRICES.heal,"label":"回復（HP2）"})
	stock.append({"kind":"ammo","price":SUPPLY_PRICES.ammo,"label":"弾薬補給"})
	# A counter-like row: the most central position where every slot is clear; otherwise each item searches alone.
	var slots := shop_row(game,taken,stock.size())
	var placed: Array = []
	for entry in stock:
		var point = slots[placed.size()] if not slots.is_empty() else Reward.placement(game,taken)
		if point == null: break
		entry.id = "%s:shop%d" % [progress.room_id,placed.size()]
		entry.pos = point
		entry.sold = false
		taken.append(point)
		placed.append(entry)
	return placed

static func shop_row(game, taken: Array, count: int) -> Array:
	var center: Vector2 = game.arena.field_rect.get_center()
	var doors: Array = game.room_data(game.exploration.room_id).doors
	var free := func(point: Vector2) -> bool:
		if game.arena.solid(point,28): return false
		if taken.any(func(other): return point.distance_to(other) < 80): return false
		return doors.all(func(door): return point.distance_to(door.position) > 112 and point.distance_to(door.arrival) > 80)
	var best: Array = []
	var best_score := INF
	for dy in range(-6,7):
		for dx in range(-6,7):
			var origin := center+Vector2(dx,dy)*48
			var score := origin.distance_squared_to(center)
			if score >= best_score: continue
			var row: Array = []
			for index in range(count): row.append(origin+Vector2((index-(count-1)*.5)*104,0))
			if not row.all(free) or game.arena.line_blocked(row[0],row[-1]): continue
			best = row
			best_score = score
	return best

static func on_altar(game) -> bool:
	return game.arena.runtime_definition.placements.any(func(p): return p.placement_id == "authored_altar")

# In the chapel the offering is made in front of its altar; elsewhere at the most central free point.
static func altar_point(game, taken: Array) -> Variant:
	for placement in game.arena.runtime_definition.placements:
		if placement.placement_id == "authored_altar":
			var point: Vector2 = placement.position+Vector2(0,48)
			if not game.arena.solid(point,24): return point
	return Reward.placement(game,taken)

# The interactable nearest the player within reach, as {kind, entry}.
static func nearby(game) -> Dictionary:
	if game.floor_data.is_empty(): return {}
	var room: Dictionary = game.exploration.room_state(game.exploration.room_id)
	var options: Array = []
	for item in room.get("shop",[]):
		if not item.sold: options.append({"kind":"shop","entry":item,"pos":item.pos})
	if room.has("altar") and not room.altar.used and room.altar.pos != null: options.append({"kind":"altar","entry":room.altar,"pos":room.altar.pos})
	if room.has("challenge") and room.challenge.state == "idle" and room.challenge.pos != null: options.append({"kind":"challenge","entry":room.challenge,"pos":room.challenge.pos})
	if room.get("teleporter") != null: options.append({"kind":"teleporter","entry":{},"pos":room.teleporter})
	var player: Vector2 = game.players[0].state.pos
	var best := {}
	var nearest := RADIUS+1
	for option in options:
		var distance: float = player.distance_to(option.pos)
		if distance <= RADIUS and distance < nearest and not game.arena.line_blocked(player,option.pos):
			best = option
			nearest = distance
	return best

static func gold(game) -> int:
	return game.exploration.inventory.gold[0]

static func hint(game) -> String:
	var option := nearby(game)
	if option.is_empty(): return ""
	match option.kind:
		"shop":
			var item: Dictionary = option.entry
			return "F：%s を %dG で購入（所持 %dG）" % [item.label,item.price,gold(game)]
		"altar": return "F：HPを1捧げて祭壇の恵みを受ける" if game.players[0].state.hp > 1 else "祭壇：HPが2以上必要です"
		"challenge": return "F：試練を始める（扉が閉じ、%d波の敵。突破でA/Sランクの武器）" % WAVES
		"teleporter": return "F：転送装置を使う" if destinations(game).size() > 1 else "転送装置：他の起動済み装置がありません"
	return ""

# Handles F; true when an event interactable consumed the key press.
static func use(game) -> bool:
	if not game.can_use_pickups(): return false
	var option := nearby(game)
	if option.is_empty(): return false
	if not game.door_armed: return true
	game.door_armed = false
	match option.kind:
		"shop": buy(game,option.entry)
		"altar": offer(game,option.entry)
		"challenge": begin_challenge(game,option.entry)
		"teleporter":
			if destinations(game).size() > 1: game.open_map(true)
	game.refresh_hud()
	return true

static func buy(game, item: Dictionary) -> bool:
	if item.sold: return false
	if gold(game) < int(item.price):
		game.loot_message = "資金不足：%s は %dG（所持 %dG）" % [item.label,item.price,gold(game)]
		refuse(game,item)
		return false
	var outcome: Dictionary
	if item.kind in ["heal","ammo"]: outcome = Supplies.collect(game,{"kind":item.kind,"taken":false})
	else: outcome = Loot.collect({"id":item.id,"kind":item.kind,"item":item.item,"label":item.label},game.exploration)
	if not outcome.acquired:
		game.loot_message = outcome.message+"（代金は払っていません）"
		refuse(game,item)
		return false
	game.exploration.inventory.gold[0] -= int(item.price)
	item.sold = true
	game.loot_message = "%s を購入しました（残り %dG）" % [item.label,gold(game)]
	game.sound.play_sound("ui_purchase")
	game.fx.burst(item.pos,Color("ffd35a"),14,150.0,.6)
	game.fx_floor.ring(item.pos,Color("ffd35a"),8,48,.4,3)
	game.fx.float_text(item.pos+Vector2(0,-40),"-%dG" % int(item.price),Color("ffd35a"))
	game.rebuild_events()
	return true

# Refusal: blocked sound and the price tag shakes.
static func refuse(game, item: Dictionary) -> void:
	game.sound.play_sound("ui_blocked")
	for node in game.event_nodes:
		if is_instance_valid(node) and node.entry == item: node.shake = .35

static func offer(game, altar: Dictionary) -> bool:
	var player = game.players[0]
	if altar.used: return false
	if player.state.hp <= 1:
		game.loot_message = "祭壇：HPが2以上必要です"
		return false
	player.state.hp -= 1.0
	player.trim_rally()
	player.sync_visual()
	altar.used = true
	game.sound.play_sound("hit")
	var bowl: Vector2 = altar.pos+(Vector2(0,-118) if on_altar(game) else Vector2(0,-34))
	game.fx.stream(player.state.pos+Vector2(0,-30),bowl,Color(1,.25,.3),16,.7)
	game.fx.pillar(bowl+Vector2(0,20),Color(1,.3,.3),240,.9,40)
	game.fx.burst(bowl,Color(1,.4,.35),16,160,.7)
	game.fx.screen_flash(Color(.8,.1,.15),.35)
	if Reward.create(game,"altar",Reward.relic_pool(game.exploration),"relic"):
		game.rebuild_chest()
		game.chest_node.spawning = .4
		game.sound.play_sound("chest_spawn")
		game.loot_message = "祭壇が応えた · レリックの宝箱が現れました"
	else:
		game.exploration.inventory.gold[0] += 5
		game.loot_message = "祭壇が応えた · 5Gを得ました"
	game.rebuild_events()
	return true

static func begin_challenge(game, challenge: Dictionary) -> bool:
	if challenge.state != "idle": return false
	challenge.state = "active"
	challenge.wave = 1
	game.rebuild_events()
	game.sound.play_sound("danger_warning")
	game.fx_floor.ring(challenge.pos,Color(1,.78,.3),20,220,.7,5)
	game.fx.burst(challenge.pos+Vector2(0,-30),Color(1,.78,.3),12,140,.5)
	spawn_wave(game,challenge)
	return true

static func spawn_wave(game, challenge: Dictionary) -> void:
	var room: Dictionary = game.exploration.room_state(game.exploration.room_id)
	var template: String = game.floor_data.rooms[game.exploration.room_id].template_id
	var ids: Array = Encounter.production_composition(template,true,3+int(challenge.wave))
	ids.append("runner_sentry" if challenge.wave < WAVES else "ram_sentry")
	room.enemy_ids = ids
	if Encounter.spawn(game,room):
		game.loot_message = "試練 第%d波 / %d" % [challenge.wave,WAVES]
		game.fx.show_banner("試練  第%d波 / %d" % [challenge.wave,WAVES],Color(1,.82,.4))
		if challenge.wave > 1: game.sound.play_sound("ui_expand")
		# Warning circles last while the new enemies hold still on entry.
		for actor in game.players.slice(1):
			game.fx_floor.warning(actor.state.pos,34,maxf(float(actor.get("attack_time")),.5))

# After a cleared wave: the next wave, or the prize. True when the challenge owned the clear.
static func on_cleared(game) -> bool:
	var room: Dictionary = game.exploration.room_state(game.exploration.room_id)
	if not room.has("challenge") or room.challenge.state != "active": return false
	var challenge: Dictionary = room.challenge
	if challenge.wave < WAVES:
		challenge.wave += 1
		spawn_wave(game,challenge)
		return true
	challenge.state = "done"
	game.sound.play_sound("rare_pickup")
	game.fx.show_banner("試練突破！",Color(1,.85,.45),1.8)
	game.fx.burst(game.players[0].state.pos+Vector2(0,-30),Color(1,.82,.4),24,220,.9)
	var pool: Array = Reward.weapon_pool(false).filter(func(id): return Weapons.definition(id).rarity in ["A","S"])
	if Reward.create(game,"challenge",pool,"weapon"):
		game.rebuild_chest()
		game.chest_node.spawning = .4
		game.sound.play_sound("chest_spawn")
		game.loot_message = "試練を突破 · 報酬の宝箱が現れました"
	else:
		game.loot_message = "試練を突破"
	game.rebuild_events()
	return true

# Visited teleporter rooms that are safe to arrive in.
static func destinations(game) -> Array:
	var result: Array = []
	for id in game.exploration.visited_rooms:
		if not has_teleporter(game,id): continue
		var room: Dictionary = game.exploration.room_state(id)
		if room.get("teleporter") == null or room.get("encounter","none") == "active": continue
		if game.floor_data.rooms[id].role == "normal" and room.get("encounter","none") != "cleared" and id != game.exploration.room_id: continue
		result.append(id)
	return result

static func teleport(game, target: String) -> bool:
	if target == game.exploration.room_id or target not in destinations(game): return false
	var pad: Vector2 = game.exploration.room_state(target).teleporter
	var arrival: Vector2 = pad+PAD_ARRIVAL
	var field = game.room_data(target).field
	if not preload("res://scripts/world/room_reachability.gd").clear_point(field,arrival): arrival = pad
	if not game.move_to_room(target,arrival): return false
	game.sound.play_sound("energy")
	game.fx.pillar(pad,Color(.55,.85,1),280,.8,52)
	game.fx_floor.ring(pad,Color(.55,.85,1),10,110,.6,5)
	game.fx.burst(arrival+Vector2(0,-20),Color(.65,.9,1),16,170,.6,120)
	game.fx.screen_flash(Color(.6,.85,1),.3)
	return true

class EventNode extends Node2D:
	var kind := ""
	var entry: Dictionary = {}
	var active := true
	var on_altar := false
	var game
	var shake := 0.0
	var time := 0.0
	func _process(delta: float) -> void:
		if game != null and game.paused: return
		time += delta
		shake = maxf(shake-delta,0)
		queue_redraw()
	# Stateless rising motes: each follows a looping phase, so they need no storage and freeze with time.
	func motes(origin: Vector2, color: Color, count: int, spread: float, rise: float, period: float) -> void:
		for index in range(count):
			var phase := fmod(time/period+float(index)/count,1.0)
			var x := sin(index*2.4+time*1.3)*spread
			draw_circle(origin+Vector2(x,-rise*phase),2.2*(1.0-phase)+.8,Color(color,color.a*(1.0-phase)))
	func _draw() -> void:
		var font := ThemeDB.fallback_font
		match kind:
			"teleporter":
				var glow := .55+.25*sin(time*3.0) if active else .2
				draw_set_transform(Vector2.ZERO,0,Vector2(1,.5))
				draw_circle(Vector2.ZERO,34,Color("1d2638"))
				draw_arc(Vector2.ZERO,34,0,TAU,40,Color(.45,.75,1,glow),4)
				draw_arc(Vector2.ZERO,22,0,TAU,32,Color(.6,.85,1,glow*.8),3)
				draw_circle(Vector2.ZERO,10,Color(.7,.9,1,glow))
				draw_set_transform(Vector2.ZERO)
				if active: motes(Vector2.ZERO,Color(.65,.9,1,.8),8,22,70,1.8)
			"altar":
				# In the chapel the flame burns in the real altar's bowl; elsewhere a small stone altar is drawn.
				var bowl := Vector2(0,-118) if on_altar else Vector2(0,-34)
				if not on_altar:
					draw_rect(Rect2(-22,-26,44,26),Color("4a4450"))
					draw_rect(Rect2(-26,-4,52,8),Color("39333d"))
				if active:
					var flicker := 2.0*sin(time*7.0)
					draw_circle(bowl,14+flicker,Color(.9,.15,.2,.25))
					draw_circle(bowl+Vector2(0,-4),8+flicker*.5,Color(1,.3,.3,.9))
					draw_circle(bowl+Vector2(0,-8),4,Color(1,.8,.6,.95))
					motes(bowl+Vector2(0,-10),Color(1,.45,.3,.9),6,8,46,1.1)
			"challenge":
				var tint := Color(1,.78,.3,.9 if active else .25)
				draw_set_transform(Vector2(0,6),0,Vector2(1,.5))
				draw_arc(Vector2.ZERO,40,0,TAU,40,Color(tint,tint.a*(.6+.3*sin(time*3.0))),4)
				draw_set_transform(Vector2.ZERO)
				draw_rect(Rect2(-20,-44,40,44),Color("5a5248"))
				draw_rect(Rect2(-20,-44,40,6),Color("736a5d"))
				draw_rect(Rect2(-26,-4,52,10),Color("463f37"))
				draw_line(Vector2(-11,-34),Vector2(11,-12),tint,4)
				draw_line(Vector2(11,-34),Vector2(-11,-12),tint,4)
		if kind == "shop":
			# Supplies draw their own name under the icon, so their price sits one line lower.
			var y := 58.0 if entry.kind in ["heal","ammo"] else 40.0
			var jolt := sin(shake*60.0)*6.0*shake/.35
			draw_string(font,Vector2(-14+jolt,y),"%dG" % int(entry.price),HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color("ffd35a"))

static func rebuild(game, nodes: Array) -> void:
	for node in nodes:
		if is_instance_valid(node):
			node.get_parent().remove_child(node)
			node.queue_free()
	nodes.clear()
	if game.floor_data.is_empty(): return
	var room: Dictionary = game.exploration.room_state(game.exploration.room_id)
	var layer = game.arena.get_node("Players")
	if room.get("teleporter") != null:
		var pad := EventNode.new()
		pad.game = game
		pad.kind = "teleporter"
		pad.position = room.teleporter
		pad.active = room.get("encounter","none") != "active"
		# The pad lies on the floor under actors.
		pad.z_index = -1
		layer.add_child(pad)
		nodes.append(pad)
	for item in room.get("shop",[]):
		if item.sold: continue
		var node := EventNode.new()
		node.game = game
		node.kind = "shop"
		node.entry = item
		node.position = item.pos
		if item.kind in ["heal","ammo"]:
			var supply := preload("res://scripts/world/exploration_supply.gd").new()
			supply.kind = item.kind
			node.add_child(supply)
		else:
			var sprite := Sprite2D.new()
			sprite.texture = Weapons.art(item.item) if item.kind == "weapon" else Art.texture("relic_%02d" % item.item)
			sprite.scale = Vector2.ONE*45.0/maxf(sprite.texture.get_width(),sprite.texture.get_height())
			node.add_child(sprite)
		layer.add_child(node)
		nodes.append(node)
	for key in ["altar","challenge"]:
		if not room.has(key) or room[key].pos == null: continue
		var node := EventNode.new()
		node.game = game
		node.kind = key
		node.entry = room[key]
		node.position = room[key].pos
		node.active = not room[key].get("used",false) and room[key].get("state","idle") == "idle"
		node.on_altar = key == "altar" and game.arena.runtime_definition.placements.any(func(p): return p.placement_id == "authored_altar")
		layer.add_child(node)
		nodes.append(node)
