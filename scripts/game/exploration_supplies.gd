extends RefCounted
const Reward = preload("res://scripts/game/exploration_reward.gd")
const Loadout = preload("res://scripts/game/exploration_loadout.gd")

static func ensure(game) -> bool:
	var progress = game.exploration
	if progress.status != "active" or progress.encounter_status != "cleared" or game.floor_data.is_empty(): return false
	if game.floor_data.rooms[progress.room_id].role != "normal": return false
	var room: Dictionary = progress.room_state(progress.room_id)
	if room.has("supplies"): return false
	var cleared: int = progress.room_states.values().filter(func(value): return value.encounter == "cleared").size()
	var kinds: Array = []
	if cleared%2 == 0: kinds.append("ammo")
	if cleared%3 == 0: kinds.append("heal")
	var excluded: Array = []
	if room.has("reward"): excluded.append(room.reward.pos)
	var items: Array = []
	for kind in kinds:
		var point = Reward.placement(game,excluded)
		if point == null:
			push_error("No reachable supply placement: "+progress.room_id)
			return false
		items.append({"id":progress.room_id+":"+kind,"kind":kind,"pos":point,"taken":false})
		excluded.append(point)
	room.supplies = items
	return true

static func entries(game) -> Array:
	return game.exploration.room_state(game.exploration.room_id).get("supplies",[])

static func nearby(game) -> Dictionary:
	var result := {}
	var nearest := 65.0
	for entry in entries(game):
		var distance: float = game.players[0].state.pos.distance_to(entry.pos)
		if not entry.taken and distance <= 64 and distance < nearest and not game.arena.line_blocked(game.players[0].state.pos,entry.pos):
			result = entry
			nearest = distance
	return result

static func collect(game, entry: Dictionary) -> Dictionary:
	var player = game.players[0]
	if entry.taken or game.exploration.status != "active" or player.state.hp <= 0: return {"acquired":false,"message":"取得できません"}
	var gained := 0.0
	if entry.kind == "heal":
		gained = minf(2.0,player.state.max_hp-player.state.hp)
		if gained > 0:
			player.state.hp += gained
			player.trim_rally()
			player.sync_visual()
	else:
		gained = player.refill_ammo()
		if gained > 0: Loadout.capture(player,game.exploration.weapon_bank)
	if gained <= 0:
		return {"acquired":false,"message":"HP満タン：回復品を残しました" if entry.kind == "heal" else "弾薬満タン／装備なし：補給品を残しました"}
	entry.taken = true
	return {"acquired":true,"message":"HPを%.1f回復しました" % gained if entry.kind == "heal" else "装備中の武器の予備弾薬を補給しました"}
