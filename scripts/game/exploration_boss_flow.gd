extends RefCounted
const Reward = preload("res://scripts/game/exploration_reward.gd")
const Relics = preload("res://scripts/catalog/relic_catalog.gd")
const COINS := 5
const REWARD_DELAY := preload("res://scripts/visuals/enemy_death.gd").BOSS_DURATION+.1

static func is_room(game) -> bool:
	return not game.floor_data.is_empty() and game.floor_data.rooms[game.exploration.room_id].role == "boss"

static func begin_intro(game) -> void:
	var boss = game.players[1]
	boss.startup_total = .8 if game.boss_intro_seen else 2.4
	boss.attack_time = boss.startup_total
	game.boss_intro_seen = true
	game.exploration.room_state(game.exploration.room_id).intro_vent = false
	game.get_node("/root/Music").play_context("")
	game.clear_action_inputs()
	game.fire_requires_release = true

static func step_intro(game, dt: float) -> void:
	var boss = game.players[1]
	boss.attack_time = maxf(0,boss.attack_time-dt)
	boss.step_presentation(dt)
	var room: Dictionary = game.exploration.room_state(game.exploration.room_id)
	if boss.attack_time <= boss.startup_total*.35 and not room.get("intro_vent",false):
		room.intro_vent = true
		game.sound.play_sound("boss_vent")
		for n in range(8):
			boss.particles.append({"pos":boss.state.pos+Vector2((-1 if n%2 == 0 else 1)*40,-65),"velocity":Vector2((-1 if n%2 == 0 else 1)*35,-20-n*3),"life":.7,"total":.7,"smoke":true,"size":7.0})
	if boss.attack_time <= 0: finish_intro(game)
	boss.sync_visual()

static func finish_intro(game) -> void:
	if not game.boss_intro() or game.paused: return
	game.players[1].attack_phase = "chase"
	game.players[1].attack_time = 0
	game.clear_action_inputs()
	game.fire_requires_release = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	game.get_node("/root/Music").play_context("boss")

static func begin_reward(game, defeated_at: Vector2) -> void:
	var room: Dictionary = game.exploration.room_state(game.exploration.room_id)
	if room.has("reward"): return
	var point = Reward.placement(game)
	if not game.arena.solid(defeated_at,24) and not game.arena.line_blocked(game.players[0].state.pos,defeated_at): point = defeated_at
	if point == null: point = game.players[0].state.pos
	room.reward = {"id":game.exploration.room_id+":boss-chest","source":"boss","kind":"relic",
		"label":"鋳造機の遺産","pos":point,"state":"forming","delay":REWARD_DELAY,"item":4,"claimed":false}
	game.get_node("/root/Music").play_context("")
	game.clear_action_inputs()
	game.fire_requires_release = true
	game.rebuild_chest()
	game.loot_message = ""

static func step_reward(game, dt: float) -> void:
	var reward := Reward.current(game)
	if reward.get("source","") != "boss" or reward.state != "forming": return
	reward.delay = maxf(0,reward.delay-dt)
	if reward.delay <= 0:
		reward.state = "closed"
		game.chest_node.spawning = .4
		game.sound.play_sound("chest_spawn")
		game.loot_message = ""

static func blocks_exit(game) -> bool:
	return is_room(game) and game.exploration.encounter_status == "cleared" and Reward.current(game).get("state","") in ["forming","closed"]

static func claim(game) -> bool:
	var reward := Reward.current(game)
	if game.paused or not Reward.nearby(game): return false
	if game.phase != "play" or game.exploration.status != "active" or game.players[0].state.hp <= 0: return false
	if reward.get("source","") != "boss" or reward.state != "open" or reward.get("claimed",false): return false
	if game.chest_node.opening > 0: return false
	if not game.exploration.inventory.store_field_relic(reward.item):
		game.loot_message = "取得できません · Tabでバッグを整理してください"
		return false
	reward.claimed = true
	reward.state = "empty"
	game.exploration.collected_loot[reward.id] = true
	game.exploration.inventory.gold[0] += COINS
	game.sound.play_sound("rare_pickup")
	game.loot_message = str(Relics.definition(reward.item).name)+"を控えへ取得 · 5G獲得"
	game.chest_node.queue_redraw()
	return true
