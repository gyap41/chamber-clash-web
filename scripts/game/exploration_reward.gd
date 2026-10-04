extends RefCounted
const Navigation = preload("res://scripts/ai/cpu_navigation.gd")
const Weapons = preload("res://scripts/catalog/weapon_catalog.gd")
const Relics = preload("res://scripts/catalog/relic_catalog.gd")
const Items = preload("res://scripts/game/item_identity.gd")

# First-clear and treasure rewards are independent guarantees.
static func ensure(game) -> bool:
	var progress = game.exploration
	if progress.status != "active" or progress.encounter_status != "cleared": return false
	if not has_source(progress,"first_clear"):
		return create(game,"first_clear",weapon_pool(true))
	var cleared := 0
	for id in progress.room_states:
		if progress.room_states[id].encounter == "cleared" and game.floor_data.get("rooms",{}).get(id,{}).get("role","") == "normal": cleared += 1
	if cleared >= 3 and not has_source(progress,"third_clear"):
		return create(game,"third_clear",weapon_pool(false))
	return false

static func has_source(progress, source: String) -> bool:
	return progress.room_states.values().any(func(value): return value.get("reward",{}).get("source","") == source)

static func weapon_pool(early: bool) -> Array:
	return Weapons.SUPPORTED.filter(func(id):
		var definition := Weapons.definition(id)
		return id != 0 and not definition.get("exclusive",false) and (not early or definition.rarity != "S"))

static func known_items(progress, kind: String) -> Array:
	var result: Array = []
	for token in progress.inventory.builds[0].owned:
		if kind == "weapon" and Items.is_gun(token): result.append(Items.gun_id(token))
		elif kind == "relic" and Items.is_relic(token): result.append(Items.relic_id(token))
	for room in progress.room_states.values():
		var reward: Dictionary = room.get("reward",{})
		if reward.get("kind","") == kind: result.append(int(reward.item))
	var unique: Array = []
	for id in result:
		if id not in unique: unique.append(id)
	return unique

static func relic_pool(progress) -> Array:
	var guns := known_items(progress,"weapon")
	var bounce := guns.any(func(id): return int(Weapons.definition(id).get("bounce",0)) > 0)
	bounce = bounce or 2 in known_items(progress,"relic")
	var returning := guns.any(func(id): return Weapons.definition(id).get("boomerang",false))
	var fragments := guns.any(func(id):
		var definition := Weapons.definition(id)
		return definition.get("split",false) or definition.get("clover",false) or definition.get("parcel",false))
	return Relics.SUPPORTED.filter(func(id):
		if id in [4,34]: return false # Boss reward; duel chest timer has no exploration effect.
		if id in [11,12,31] and not bounce: return false
		if id in [14,33] and not returning: return false
		if id == 32 and not fragments: return false
		if id in [8,16,30] and guns.size() < 2: return false
		return true)

static func ensure_treasure(game) -> bool:
	if game.floor_data.is_empty() or game.exploration.status != "active": return false
	if game.floor_data.rooms[game.exploration.room_id].role != "treasure": return false
	return create(game,"treasure",relic_pool(game.exploration),"relic")

static func create(game, source: String, pool: Array, kind: String = "weapon") -> bool:
	var progress = game.exploration
	var room: Dictionary = progress.room_state(progress.room_id)
	if room.has("reward"): return false
	var known := known_items(progress,kind)
	var candidates := pool.filter(func(id): return (id not in known or (kind == "relic" and Relics.stackable(id))) and fits_bag(progress,id,kind))
	if candidates.is_empty(): return false
	var point = placement(game)
	if point == null:
		push_error("No reachable reward placement: "+progress.room_id)
		return false
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(progress.seed_value)+":"+progress.room_id+":"+source+":reward-v2")
	var item: int = candidates[rng.randi_range(0,candidates.size()-1)]
	room.reward = {"id":progress.room_id+":chest", "source":source,
		"kind":kind,"item":item,"label":str((Weapons.definition(item) if kind == "weapon" else Relics.definition(item)).name),
		"pos":point,"state":"closed"}
	return true

# Ignore occupied cells: rearranging gear is allowed, enlarging this run's bag is not.
static func fits_bag(progress, id: int, kind: String) -> bool:
	var inventory = progress.inventory
	var token = Items.gun_token(id) if kind == "weapon" else Items.relic_token(id,0)
	var cells: Dictionary = inventory.usable_cells(0)
	return cells.keys().any(func(anchor): return inventory.BuildGrid.fits(token,anchor,cells,{}))

# Search only reachable floor, preferring the room center and keeping interactions apart.
static func placement(game, excluded: Array = []) -> Variant:
	var start: Vector2 = game.players[0].state.pos
	# Event interactables (teleporter pad, shop stock, altar, challenge) keep their own space.
	var room: Dictionary = game.exploration.room_state(game.exploration.room_id)
	excluded = excluded.duplicate()
	if room.get("teleporter") != null: excluded.append(room.teleporter)
	if room.get("shop_sign") != null: excluded.append(room.shop_sign)
	for item in room.get("shop",[]): excluded.append(item.pos)
	for key in ["altar","challenge"]:
		if room.has(key) and room[key].pos != null: excluded.append(room[key].pos)
	var pending := [Vector2i.ZERO]
	var seen := {Vector2i.ZERO:true}
	var cursor := 0
	var best: Variant = null
	var best_score := INF
	while cursor < pending.size() and cursor < 16384:
		var cell: Vector2i = pending[cursor]
		cursor += 1
		var point := start+Vector2(cell)*32
		var door_clear: bool = game.room_data(game.exploration.room_id).doors.all(func(door): return point.distance_to(door.position) > 112 and point.distance_to(door.arrival) > 80)
		var score := point.distance_squared_to(game.arena.field_rect.get_center())
		if door_clear and score < best_score and excluded.all(func(other): return point.distance_to(other) >= 96) and not game.arena.solid(point,24):
			best = point
			best_score = score
		for offset in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			var next: Vector2i = cell+offset
			if not seen.has(next) and Navigation.segment_clear(game.arena,point,start+Vector2(next)*32):
				seen[next] = true
				pending.append(next)
	return best

static func current(game) -> Dictionary:
	return game.exploration.room_state(game.exploration.room_id).get("reward",{})

static func nearby(game) -> bool:
	var reward := current(game)
	if reward.is_empty() or reward.state in ["empty","forming"]: return false
	var targets := [reward.pos]
	if reward.state == "open": targets.append(reward.pos+reward.get("drop_offset",Vector2.ZERO))
	for target in targets:
		if game.players[0].state.pos.distance_to(target) <= 64 and not game.arena.line_blocked(game.players[0].state.pos,target): return true
	return false

# Presentation RNG is independent of reward/encounter rolls. Supports future multi-drop slots.
static func scatter_offsets(arena, origin: Vector2, seed_value: int, count: int) -> Array[Vector2]:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var result: Array[Vector2] = []
	var start := rng.randf_range(0,TAU)
	for index in range(count):
		var chosen := Vector2.ZERO
		var best_score := -INF
		for candidate in range(32):
			var angle := start+TAU*index/maxi(count,1)+candidate*TAU/32
			var offset := Vector2.from_angle(angle)*60
			if arena.solid(origin+offset,22) or arena.line_blocked(origin,origin+offset): continue
			var separation := 120.0
			for previous in result: separation = minf(separation,offset.distance_to(previous))
			# Prefer the front/sides so the open lid does not conceal the item.
			var score := separation-(35.0 if offset.y < -20 else 0.0)-candidate*.01
			if score > best_score:
				chosen = offset
				best_score = score
		result.append(chosen) # Very tight spaces keep loot at the reachable chest.
	return result
