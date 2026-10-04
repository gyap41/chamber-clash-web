extends SceneTree
const Weapons = preload("res://scripts/catalog/weapon_catalog.gd")
const Events = preload("res://scripts/game/exploration_events.gd")
var game
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	game = load("res://scenes/game/exploration.tscn").instantiate()
	game.encounters_enabled = false
	root.add_child(game)
	game.set_physics_process(false)
	game.set_pause_reason("focus",false)
	var hero = game.players[0]
	var origin: String = game.exploration.room_id
	var door: Dictionary = game.room_data(origin).doors[0]
	hero.state.pos = door.position
	game.set_pause_reason("menu",true)
	game.step_auto_door()
	assert(game.exploration.room_id == origin,"Menus block automatic travel")
	game.set_pause_reason("menu",false)
	game.exploration.encounter_status = "active"
	game.step_auto_door()
	assert(game.exploration.room_id == origin,"Combat blocks automatic travel")
	game.exploration.encounter_status = "none"
	game.door_armed = false # No F release is needed.
	game.step_auto_door()
	assert(game.exploration.room_id == door.target_room)
	var arrival: Vector2 = hero.state.pos
	var back: Dictionary = game.room_data(game.exploration.room_id).doors[0]
	hero.state.pos = back.position
	game.step_auto_door()
	assert(game.exploration.room_id == door.target_room,"Arrival cannot immediately bounce back")
	hero.state.pos = arrival
	game.step_auto_door()
	hero.state.pos = back.position
	game.step_auto_door()
	assert(game.exploration.room_id == origin,"Leaving threshold rearms travel")
	game.refresh_hud()
	assert(not game.hud.get_node("Root/Heading").visible)
	for node in game.doors: assert(not node.caption.visible)
	hero.weapon().clip = 0
	hero.start_reload()
	hero.sync_visual()
	assert(hero.get_node("ReloadProgress").visible and not hero.get_node("ReloadProgress/Time").visible)
	for id in Weapons.SUPPORTED:
		var icon := Weapons.pickup_art(id)
		var used := icon.get_image().get_used_rect()
		assert(used.has_area() and Vector2(used.size).is_equal_approx(icon.get_size()),"Pickup art must fit visible pixels: %d" % id)
	var merchant := Events.EventNode.new()
	merchant.kind = "sign"
	merchant.game = game
	game.add_child(merchant)
	merchant.say("品物の前でFを押してごらん。効き目を確かめてから買えばいい。")
	assert(merchant.bubble.visible and merchant.bubble.get_node("Text").text.begins_with("品物"))
	game.paused = true
	merchant._process(10)
	assert(merchant.speech_remaining == 6.0,"Speech freezes while paused")
	game.paused = false
	merchant._process(7)
	assert(not merchant.bubble.visible,"Old dialogue disappears")
	game.queue_free()
	await process_frame
	print("PASS: automatic doors, arrival latch, quiet overhead UI, fitted pickup art and merchant bubble")
	quit()
