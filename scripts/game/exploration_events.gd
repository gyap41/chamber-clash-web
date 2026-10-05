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
const SUPPLY_PRICES := {"heal":8,"ammo":6}
const WAVES := 3
const PAD_ARRIVAL := Vector2(0,64)

static func role(game) -> String:
	if game.floor_data.is_empty(): return ""
	return game.floor_data.rooms[game.exploration.room_id].role

static func has_teleporter(game, id: String) -> bool:
	return not game.floor_data.is_empty() and game.floor_data.rooms[id].role != "boss"

# Creates this room's event state on first entry (positions are searched from the arrival point).
static func prepare(game) -> void:
	if game.floor_data.is_empty() or game.exploration.status != "active": return
	var room: Dictionary = game.exploration.room_state(game.exploration.room_id)
	var taken: Array = []
	if room.has("reward"): taken.append(room.reward.pos)
	match role(game):
		"shop":
			if not room.has("shop"):
				room.shop = shop_stock(game,taken)
				room.shop_sign = sign_point(game,room.shop)
		"altar":
			if not room.has("altar"): room.altar = {"pos":altar_point(game,taken),"used":false}
		"challenge":
			if not room.has("challenge"): room.challenge = {"pos":Reward.placement(game,taken),"state":"idle","wave":0}
	for key in ["shop","altar","challenge"]:
		if room.has(key):
			if key == "shop":
				for item in room.shop: taken.append(item.pos)
			else: taken.append(room[key].pos)
	if room.get("shop_sign") != null: taken.append(room.shop_sign)
	if has_teleporter(game,game.exploration.room_id) and not room.has("teleporter"):
		room.teleporter = Reward.placement(game,taken)

static func shop_stock(game, taken: Array) -> Array:
	var progress = game.exploration
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(progress.seed_value)+":"+progress.room_id+":shop-v1")
	var known_weapons := Reward.known_items(progress,"weapon")
	var weapons: Array = Reward.weapon_pool(false).filter(func(id): return id not in known_weapons and Shop.WEAPON_PRICES[id] > 0)
	var relics: Array = Reward.relic_pool(progress).filter(func(id): return Relics.stackable(id) or id not in Reward.known_items(progress,"relic"))
	var stock: Array = []
	for count in range(2):
		if weapons.is_empty(): break
		var item: int = weapons.pop_at(rng.randi_range(0,weapons.size()-1))
		stock.append({"kind":"weapon","item":item,"price":{"C":10,"B":16,"A":24,"S":36}[Weapons.definition(item).rarity],"label":str(Weapons.definition(item).name)})
	if not relics.is_empty():
		var relic: int = relics[rng.randi_range(0,relics.size()-1)]
		stock.append({"kind":"relic","item":relic,"price":{"C":8,"B":14,"A":22}[Relics.rarity(relic)],"label":str(Relics.definition(relic).name)})
	stock.append({"kind":"heal","price":SUPPLY_PRICES.heal,"label":"回復（HP2）"})
	stock.append({"kind":"ammo","price":SUPPLY_PRICES.ammo,"label":"弾薬補給"})
	stock.append({"kind":"expansion","price":8,"label":"バッグを1マス拡張","cell":Vector2i(-1,-1)})
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

# 2026-10-05: scattered stock needs clearance from EVERY pedestal, not just the row ends.
static func sign_point(game, stock: Array) -> Variant:
	if stock.is_empty(): return null
	var ends: Array = [stock[0].pos+Vector2(-144,0),stock[-1].pos+Vector2(144,0)]
	var center: Vector2 = game.arena.field_rect.get_center()
	var candidates: Array = []
	for dy in range(-8,9):
		for dx in range(-12,13): candidates.append(center+Vector2(dx,dy)*32)
	candidates.sort_custom(func(a: Vector2,b: Vector2): return a.distance_squared_to(center) < b.distance_squared_to(center))
	ends.append_array(candidates)
	for point in ends:
		var doors: Array = game.room_data(game.exploration.room_id).doors
		if game.arena.solid(point,28) or doors.any(func(door): return point.distance_to(door.position) <= 112 or point.distance_to(door.arrival) <= 80): continue
		if stock.any(func(item): return point.distance_to(item.pos) < 144): continue
		# Reserve an unobstructed place to stand in front of the merchant.
		var approach: Vector2 = point+Vector2(0,40)
		if game.arena.solid(approach,20) or game.arena.line_blocked(point,approach): continue
		return point
	return null

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
	if room.get("shop_sign") != null: options.append({"kind":"merchant","entry":room,"pos":room.shop_sign})
	for item in room.get("shop",[]):
		if not item.sold: options.append({"kind":"shop","entry":item,"pos":item.pos})
	if room.has("altar") and not room.altar.used and room.altar.pos != null: options.append({"kind":"altar","entry":room.altar,"pos":room.altar.pos})
	if room.has("challenge") and room.challenge.state == "idle" and room.challenge.pos != null: options.append({"kind":"challenge","entry":room.challenge,"pos":room.challenge.pos})
	if room.get("teleporter") != null: options.append({"kind":"teleporter","entry":{},"pos":room.teleporter})
	var player: Vector2 = game.players[0].state.pos
	var best := {}
	var merchant := {}
	var nearest := RADIUS+1
	for option in options:
		var distance: float = player.distance_to(option.pos)
		# Product inspection must remain available even in an already-created overlapping layout.
		if option.kind == "merchant":
			if distance <= RADIUS and not game.arena.line_blocked(player,option.pos): merchant = option
			continue
		if distance <= RADIUS and distance < nearest and not game.arena.line_blocked(player,option.pos):
			best = option
			nearest = distance
	return merchant if best.is_empty() else best

static func gold(game) -> int:
	return game.exploration.inventory.gold[0]

static func hint(game) -> String:
	var option := nearby(game)
	if option.is_empty(): return ""
	match option.kind:
		"merchant": return "F：煤の帳守と話す"
		"shop":
			var item: Dictionary = option.entry
			return "F：%s の効果・価格を確認（%dG ／ 所持 %dG）" % [item.label,item.price,gold(game)]
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
		"merchant":
			var lines := ["煤の帳守：その歯車貨、まだ回るね。ここでは1枚を1Gと数える。", "煤の帳守：品物の前でFを押してごらん。効き目を確かめてから買えばいい。", "煤の帳守：荷が増えたら、鞄の継ぎ目を一つ広げよう。場所は君が選ぶんだ。"]
			var count: int = option.entry.get("talk_count",0)
			game.loot_message = lines[count%lines.size()]
			option.entry.talk_count = count+1
			for node in game.event_nodes:
				if node.kind == "sign": node.say(lines[count%lines.size()].trim_prefix("煤の帳守："))
		"shop": game.open_shop(option.entry)
		"altar": offer(game,option.entry)
		"challenge": begin_challenge(game,option.entry)
		"teleporter":
			if destinations(game).size() > 1: game.open_map(true)
	game.refresh_hud()
	return true

static func purchase_reason(game, item: Dictionary) -> String:
	if item.sold: return "売り切れ"
	if gold(game) < int(item.price): return "資金不足：あと%dG必要です" % (int(item.price)-gold(game))
	var inventory = game.exploration.inventory
	if item.kind == "expansion":
		if inventory.expansion_cells().is_empty(): return "バッグは拡張上限です"
		if item.cell not in inventory.expansion_cells(): return "隣接する拡張先を選んでください"
	if item.kind == "weapon": return inventory.field_weapon_reason(0,item.item)
	if item.kind == "relic":
		if inventory.reserve_full(0): return "控え8個が満杯です。Tabで整理してください。"
		if not Relics.stackable(item.item) and item.item in inventory.Items.relic_ids(inventory.builds[0].owned): return "同種のレリックを所持済みです"
	if item.kind == "heal" and game.players[0].state.hp >= game.players[0].state.max_hp: return "HPは満タンです"
	if item.kind == "ammo":
		var needs_ammo := false
		for gun in game.players[0].inventory:
			if not game.players[0].infinite_reserve(gun.id) and gun.reserve < Weapons.definition(gun.id).stock: needs_ammo = true
		if not needs_ammo: return "装備中の予備弾薬は満タンです（無限弾薬・控えは対象外）"
	return ""

static func buy(game, item: Dictionary) -> bool:
	if item.sold: return false
	if gold(game) < int(item.price):
		game.loot_message = "資金不足：%s は %dG（所持 %dG）" % [item.label,item.price,gold(game)]
		refuse(game,item)
		return false
	var outcome: Dictionary
	if item.kind == "expansion": outcome = {"acquired":game.exploration.inventory.buy_cell(item.cell,0),"message":"拡張先を選んでください"}
	elif item.kind in ["heal","ammo"]: outcome = Supplies.collect(game,{"kind":item.kind,"taken":false})
	else: outcome = Loot.collect({"id":item.id,"kind":item.kind,"item":item.item,"label":item.label},game.exploration)
	if not outcome.acquired:
		game.loot_message = outcome.message+"（代金は払っていません）"
		refuse(game,item)
		return false
	game.exploration.inventory.gold[0] -= int(item.price)
	item.sold = item.kind != "expansion"
	game.loot_message = "%s を購入しました（残り %dG）" % [item.label,gold(game)]
	game.sound.play_sound("ui_purchase")
	game.fx.burst(item.pos,Color("ffd35a"),14,150.0,.6)
	game.fx_floor.ring(item.pos,Color("ffd35a"),8,48,.4,3)
	game.fx.float_text(item.pos+Vector2(0,-40),"-%dG" % int(item.price),Color("ffd35a"))
	if item.kind == "expansion":
		item.price += 2
		item.cell = Vector2i(-1,-1)
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
	game.sound.play_sound("altar_offer")
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
	game.sound.play_sound("challenge_start")
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
	game.sound.play_sound("teleport")
	game.fx.pillar(pad,Color(.55,.85,1),280,.8,52)
	game.fx_floor.ring(pad,Color(.55,.85,1),10,110,.6,5)
	game.fx.burst(arrival+Vector2(0,-20),Color(.65,.9,1),16,170,.6,120)
	game.fx.screen_flash(Color(.6,.85,1),.3)
	return true

class EventNode extends Node2D:
	# Generated props (docs/art/production/event-rooms, event-props-v1). Sizes are world units, feet at the origin.
	const KIT := "res://assets/stages/ashen-foundry-v2/event-props/%s.tres"
	var kind := ""
	var entry: Dictionary = {}
	var active := true
	var on_altar := false
	var game
	var shake := 0.0
	var time := 0.0
	var glow: Sprite2D
	var bubble: PanelContainer
	var speech_remaining := 0.0
	func say(text: String) -> void:
		if bubble == null:
			bubble = PanelContainer.new()
			bubble.position = Vector2(-150,-184)
			bubble.z_index = 20
			bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var style := StyleBoxFlat.new()
			style.bg_color = Color("252d32")
			style.border_color = Color("cbbd96")
			style.set_border_width_all(2)
			style.set_corner_radius_all(10)
			style.content_margin_left = 14
			style.content_margin_right = 14
			style.content_margin_top = 10
			style.content_margin_bottom = 10
			bubble.add_theme_stylebox_override("panel",style)
			var label := Label.new()
			label.name = "Text"
			label.custom_minimum_size.x = 272
			label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			label.add_theme_font_size_override("font_size",14)
			label.add_theme_color_override("font_color",Color("f5edd8"))
			bubble.add_child(label)
			add_child(bubble)
		bubble.get_node("Text").text = text
		bubble.reset_size()
		bubble.visible = true
		speech_remaining = 6.0
	func _process(delta: float) -> void:
		if game != null and game.paused: return
		time += delta
		speech_remaining = maxf(0,speech_remaining-delta)
		if bubble != null:
			bubble.visible = speech_remaining > 0
			bubble.modulate.a = minf(1,speech_remaining/.25)
			bubble.position.y = -114-bubble.size.y+8*(1.0-minf(1,(6.0-speech_remaining)/.15))
		shake = maxf(shake-delta,0)
		if glow != null:
			glow.visible = active
			glow.modulate.a = .55+.35*sin(time*3.0)
		queue_redraw()
	# Additive light layer drawn over the prop, pulsed in _process.
	func add_glow(art: String, rect: Rect2) -> void:
		glow = Sprite2D.new()
		glow.texture = load(KIT % art)
		glow.centered = false
		glow.position = rect.position
		glow.scale = rect.size/glow.texture.get_size()
		var additive := CanvasItemMaterial.new()
		additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		glow.material = additive
		add_child(glow)
	func art(id: String, rect: Rect2, tint: Color = Color.WHITE) -> void:
		draw_texture_rect(load(KIT % id),rect,false,tint)
	# Stateless rising motes: each follows a looping phase, so they need no storage and freeze with time.
	func motes(origin: Vector2, color: Color, count: int, spread: float, rise: float, period: float) -> void:
		for index in range(count):
			var phase := fmod(time/period+float(index)/count,1.0)
			var x := sin(index*2.4+time*1.3)*spread
			draw_circle(origin+Vector2(x,-rise*phase),2.2*(1.0-phase)+.8,Color(color,color.a*(1.0-phase)))
	func _draw() -> void:
		var font := ThemeDB.fallback_font
		if kind == "sign" and speech_remaining > 0:
			draw_colored_polygon(PackedVector2Array([Vector2(-8,-115),Vector2(0,-101),Vector2(8,-115)]),Color(Color("cbbd96"),minf(1,speech_remaining/.25)))
		match kind:
			"teleporter":
				art("teleporter_base",Rect2(-52,-38,104,76),Color.WHITE if active else Color(.7,.7,.75))
				if active: motes(Vector2.ZERO,Color(.65,.9,1,.8),8,26,70,1.8)
			"altar":
				# In the chapel the flame burns in the real altar's bowl; elsewhere the small altar is drawn.
				var bowl := Vector2(0,-118) if on_altar else Vector2(0,-58)
				if not on_altar:
					draw_set_transform(Vector2(0,-2),0,Vector2(1,.35))
					draw_circle(Vector2.ZERO,30,Color(0,0,0,.3))
					draw_set_transform(Vector2.ZERO)
					art("altar_small",Rect2(-30,-66,60,66))
				if active:
					var flicker := 2.0*sin(time*7.0)
					draw_circle(bowl,14+flicker,Color(.9,.15,.2,.25))
					draw_circle(bowl+Vector2(0,-4),8+flicker*.5,Color(1,.3,.3,.9))
					draw_circle(bowl+Vector2(0,-8),4,Color(1,.8,.6,.95))
					motes(bowl+Vector2(0,-10),Color(1,.45,.3,.9),6,8,46,1.1)
			"challenge":
				var tint := Color(1,.78,.3,.9 if active else .0)
				draw_set_transform(Vector2(0,2),0,Vector2(1,.5))
				draw_circle(Vector2.ZERO,26,Color(0,0,0,.3))
				if active: draw_arc(Vector2.ZERO,42,0,TAU,40,Color(tint,tint.a*(.5+.3*sin(time*3.0))),4)
				draw_set_transform(Vector2.ZERO)
				art("challenge_plinth",Rect2(-22,-94,44,94),Color.WHITE if active else Color(.75,.75,.75))
			"sign":
				draw_set_transform(Vector2(0,-1),0,Vector2(1,.35))
				draw_circle(Vector2.ZERO,22,Color(0,0,0,.3))
				draw_set_transform(Vector2.ZERO)
				var portrait := preload("res://assets/stages/ashen-foundry-v2/event-props/merchant-v1.png")
				draw_texture_rect(portrait,Rect2(-55,-100+sin(time*1.6),110,116),false)
				draw_circle(Vector2(0,-64+sin(time*1.6)),6,Color(.3,.85,.75,.06+.03*sin(time*2.3)))
				art("shop_sign",Rect2(30,-39,28,39))
			"shop":
				draw_set_transform(Vector2(0,20),0,Vector2(1,.35))
				draw_circle(Vector2.ZERO,30,Color(0,0,0,.3))
				draw_set_transform(Vector2.ZERO)
				art("shop_stand",Rect2(-30,-20,60,44))
				var jolt := sin(shake*60.0)*6.0*shake/.35
				draw_string(font,Vector2(-24+jolt,44),"売り切れ" if entry.sold else "%dG" % int(entry.price),HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color("ffd35a"))

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
		pad.add_glow("teleporter_glow",Rect2(-52,-38,104,76))
		# The pad lies on the floor under actors.
		pad.z_index = -1
		layer.add_child(pad)
		nodes.append(pad)
	if room.get("shop_sign") != null:
		var sign := EventNode.new()
		sign.game = game
		sign.kind = "sign"
		sign.position = room.shop_sign
		layer.add_child(sign)
		nodes.append(sign)
	for item in room.get("shop",[]):
		var node := EventNode.new()
		node.game = game
		node.kind = "shop"
		node.entry = item
		node.position = item.pos
		# The item sits on the stand's cloth top.
		if item.sold: pass
		elif item.kind == "expansion":
			var label := Label.new()
			label.text = "+1"
			label.position = Vector2(-12,-25)
			node.add_child(label)
		elif item.kind in ["heal","ammo"]:
			var supply := preload("res://scripts/world/exploration_supply.gd").new()
			supply.kind = item.kind
			supply.show_label = false
			supply.position = Vector2(0,-10)
			supply.scale = Vector2.ONE*.8
			node.add_child(supply)
		else:
			var sprite := Sprite2D.new()
			sprite.texture = Weapons.pickup_art(item.item) if item.kind == "weapon" else Art.texture("relic_%02d" % item.item)
			sprite.scale = Vector2.ONE*40.0/maxf(sprite.texture.get_width(),sprite.texture.get_height())
			sprite.position = Vector2(0,-10)
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
		node.on_altar = key == "altar" and on_altar(game)
		if key == "challenge": node.add_glow("challenge_emblem_glow",Rect2(-13,-41,21,25))
		layer.add_child(node)
		nodes.append(node)
