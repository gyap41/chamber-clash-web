extends RefCounted
# Gold dropped by defeated enemies (docs/planning/FLOOR_EXPANSION_PLAN.md stage 3). Coins are room state, so
# ones left behind stay for a revisit; nearby coins drift to the player and are taken without a key press.
const LARGE := ["ram_sentry","ring_sentry","scatter_drone"]
const PULL_RADIUS := 110.0
const TAKE_RADIUS := 22.0
const PULL_SPEED := 420.0

static func value(enemy_id: String) -> int:
	if enemy_id == "furnace_warden": return 0 # The boss pays through its own reward.
	return 2 if enemy_id in LARGE else 1

static func entries(game) -> Array:
	var room: Dictionary = game.exploration.room_state(game.exploration.room_id)
	if not room.has("coins"): room.coins = []
	return room.coins

# Called after each combat step, before a cleared room retires its enemies.
static func drop(game) -> bool:
	var dropped := false
	for index in range(1,game.players.size()):
		var actor = game.players[index]
		if actor.state.hp > 0 or actor.has_meta("coins_dropped") or actor.get("spec") == null: continue
		actor.set_meta("coins_dropped",true)
		var amount := value(str(actor.spec.id))
		if amount <= 0: continue
		var list := entries(game)
		list.append({"id":"%s:coin%d" % [game.exploration.room_id,list.size()],"pos":actor.state.pos,"value":amount})
		dropped = true
	return dropped

# Returns gold taken this step.
static func step(game, dt: float) -> int:
	var taken := 0
	var player: Vector2 = game.players[0].state.pos
	var list := entries(game)
	for coin in list.duplicate():
		var distance: float = coin.pos.distance_to(player)
		if distance <= PULL_RADIUS: coin.pos = coin.pos.move_toward(player,PULL_SPEED*dt)
		if coin.pos.distance_to(player) <= TAKE_RADIUS:
			taken += int(coin.value)
			list.erase(coin)
	if taken > 0: game.exploration.inventory.gold[0] += taken
	return taken

class CoinNode extends Node2D:
	var coin: Dictionary
	var time := 0.0
	func _process(delta: float) -> void:
		time += delta
		position = coin.pos
		queue_redraw()
	func _draw() -> void:
		var lift := 3.0*sin(time*5.0+float(coin.id.hash()%7))
		draw_set_transform(Vector2(0,6),0,Vector2(1,.45))
		draw_circle(Vector2.ZERO,7,Color(0,0,0,.35))
		draw_set_transform(Vector2.ZERO)
		var radius := 7.0 if int(coin.value) <= 1 else 9.0
		draw_circle(Vector2(0,-6-lift),radius,Color("8a5a12"))
		draw_circle(Vector2(0,-6-lift),radius-1.5,Color("f2c14e"))
		draw_rect(Rect2(-1.5,-6-lift-radius*.5,3,radius),Color("fff0b0"))

static func rebuild(game, nodes: Array) -> void:
	for node in nodes:
		if is_instance_valid(node):
			node.get_parent().remove_child(node)
			node.queue_free()
	nodes.clear()
	for coin in entries(game):
		var node := CoinNode.new()
		node.coin = coin
		node.position = coin.pos
		game.arena.get_node("Players").add_child(node)
		nodes.append(node)
