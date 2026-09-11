extends Node2D
const Weapons = preload("res://scripts/catalog/weapon_catalog.gd")
const Relics = preload("res://scripts/catalog/relic_catalog.gd")
@export var first_relic_delay := 35.0
@export var relic_interval := 90.0
@export var pickup_scene: PackedScene = preload("res://scenes/world/pickup.tscn")
@export var first_supply_delay := 28.0
@export var supply_interval := 40.0
@export var first_ammo_delay := 12.0
@export var ammo_interval := 14.0
@export var legendary_time := 45.0
@export var pickup_delay := .6
@export var pickup_lifetime := 42.0
@export var touch_radius := 31.0
@export var interact_radius := 65.0
# P7 宝箱演出：武器・レリックの補給は「宝箱」として、触れるだけでは入手できない。G/Hで
# 開封を開始したプレイヤーがinteract_radius内に留まり続けた場合のみ、この秒数が経過すると
# acquire()が呼ばれて入手が確定する（無敵化はしない＝開封中も通常どおり被弾しうる）。数値は
# playtestでの調整前提の仮置き。弾薬箱は対象外（従来どおり触れるだけで即時補給）。
@export var chest_open_duration := 1.5
var game
var items: Array = []
var elapsed := 0.0
var supply_timer := 28.0
var relic_timer := 35.0
var ammo_timer := 12.0
var legendary_spawned := false
var legendary_warned := false
var notice := ""
var notice_time := 0.0
func active() -> bool:
	return game != null and game.phase == "play" and not game.paused and game.result == ""
func reset() -> void:
	for item in items:
		item.get_parent().remove_child(item)
		item.queue_free()
	items.clear()
	elapsed = 0.0
	supply_timer = first_supply_delay
	relic_timer = first_relic_delay
	ammo_timer = first_ammo_delay
	legendary_spawned = false
	legendary_warned = false
	notice = ""
	notice_time = 0.0
func announce(text: String) -> void:
	notice = text
	notice_time = 3.0
func weighted_gun(legendary: bool = false) -> int:
	var roll: float = game.supply_generator.rng.randf()
	var rarity := "S" if legendary else ("C" if roll < .35 else "B" if roll < .75 else "A")
	# P8z：SUPPORTEDを直接絞らずrarity_pool()を経由する。将来のキャラクター専用武器
	# （"exclusive": true）が宝箱から出ないようにするための一枚（weapon_catalog.gd参照）。
	var pool: Array = Weapons.rarity_pool(rarity)
	return pool[game.supply_generator.rng.randi_range(0,pool.size()-1)]
func put_item(kind: String, id: int, pos: Vector2):
	if kind not in ["weapon","ammo","relic"] or (kind == "weapon" and not Weapons.supported(id)): return null
	if kind == "relic" and not Relics.supported(id): return null
	if not game.arena.fighter_bounds.has_point(pos) or game.arena.solid(pos,18): return null
	for other in items:
		if not other.used and other.position.distance_to(pos) < 35: return null
	var item = pickup_scene.instantiate()
	$Items.add_child(item)
	item.position = pos
	item.configure(kind,id)
	items.append(item)
	item.refresh(game.players,pickup_delay,chest_open_duration)
	return item
func spawn_group(group: String, kind: String, id: int = 0) -> void:
	for marker in get_node("Spawns/"+group).get_children():
		put_item(kind,id,to_local(marker.global_position))
func launch() -> void:
	spawn_group("Ammo","ammo")
	announce("選んだ主力で開戦。武器補給は%d秒後、レジェンダリーは%d秒後" % [int(first_supply_delay),int(legendary_time)])
func periodic_supply() -> void:
	spawn_group("Weapons","weapon",weighted_gun())
	announce("武器補給：同じ武器が両サイドに出現")
func acquire(player_index: int, item, replace: bool = false) -> bool:
	if not active() or not is_instance_valid(item) or item not in items or item.used or item.age < pickup_delay or item.age >= pickup_lifetime: return false
	var player = game.players[player_index]
	if player.state.hp <= 0 or player.state.pos.distance_to(item.position) >= (interact_radius if replace else touch_radius): return false
	var message: String = player.acquire_weapon(item.gun,replace) if item.kind == "weapon" else ("全武器の予備弾を補給" if item.kind == "ammo" and player.refill_ammo() > 0 else "")
	if item.kind == "relic":
		if not replace: return false
		var reason: String = player.field_relic_reason(item.gun)
		if reason != "":
			announce(reason)
			return false
		message = Relics.definition(item.gun).name+"：レリック取得" if player.acquire_temporary(item.gun) else ""
	if message.is_empty(): return false
	game.telemetry.record("pickup",{"player":player_index,"kind":item.kind,"id":item.gun})
	item.used = true
	game.sound.play_sound("pickup")
	var color := Color("a5e9ee")
	if item.kind == "weapon": color = Weapons.rarity_color(item.gun)
	elif item.kind == "relic": color = Color(Relics.definition(item.gun).color)
	game.combat_visuals.burst(item.position,color,22)
	item.visible = false
	announce("P%d：%s" % [player_index+1,message])
	return true
func interact(player_index: int) -> void:
	if not active(): return
	var nearest = null
	var distance := interact_radius
	for item in items:
		if item.used or item.age < pickup_delay or item.age >= pickup_lifetime: continue
		var d: float = item.position.distance_to(game.players[player_index].state.pos)
		if d < distance:
			distance = d
			nearest = item
	if nearest == null: return
	if nearest.kind in ["weapon","relic"]:
		# P7 宝箱演出：即時入手ではなく開封を開始（あるいは自分がすでに開封中なら何もしない）。
		# 他プレイヤーが開封中の宝箱は横取りできない。
		if nearest.opening_player == -1 or nearest.opening_player == player_index:
			nearest.opening_player = player_index
	else:
		acquire(player_index,nearest,true)
func step(dt: float) -> void:
	if not active(): return
	elapsed += dt
	ammo_timer -= dt
	if ammo_timer <= 0:
		ammo_timer = ammo_interval
		spawn_group("Ammo","ammo")
	notice_time = maxf(0.0,notice_time-dt)
	relic_timer -= dt
	if relic_timer <= 0:
		relic_timer = relic_interval
		spawn_group("Relics","relic",game.supply_generator.shuffled(Relics.SUPPORTED)[0])
		announce("レリック補給：G / Hで仮装備・1人1個")
	supply_timer -= dt
	if supply_timer <= 0:
		supply_timer = supply_interval
		periodic_supply()
	if elapsed >= legendary_time-5.0 and not legendary_warned:
		legendary_warned = true
		announce("あと5秒：中央の上下にSレア武器を投下")
	if elapsed >= legendary_time and not legendary_spawned:
		legendary_spawned = true
		game.sound.play_sound("legendary")
		spawn_group("Legendary","weapon",weighted_gun(true))
		announce("Sレア武器が中央の上下に到着")
	for item in items:
		item.age += dt
		if item.age < pickup_lifetime:
			if item.kind == "ammo":
				for i in range(2): acquire(i,item)
			elif item.opening_player != -1:
				# P7 宝箱演出：開封中のプレイヤーがinteract_radius内に留まっている間だけ進行。
				# 無敵にはしないため、開封中も通常どおり被弾しうる。範囲外に出た／倒れたら中断。
				var opener = game.players[item.opening_player]
				if opener.state.hp > 0 and item.position.distance_to(opener.state.pos) < interact_radius:
					item.open_progress += dt
					if item.open_progress >= chest_open_duration:
						acquire(item.opening_player,item,true)
				else:
					item.opening_player = -1
					item.open_progress = 0.0
		item.refresh(game.players,pickup_delay,chest_open_duration)
	for n in range(items.size()-1,-1,-1):
		var item = items[n]
		if item.used or item.age >= pickup_lifetime:
			items.remove_at(n)
			item.get_parent().remove_child(item)
			item.queue_free()
