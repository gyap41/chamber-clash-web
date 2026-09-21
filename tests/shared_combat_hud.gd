extends SceneTree
const View = preload("res://scripts/ui/combat_hud_view.gd")
func _initialize() -> void:
	call_deferred("run")
func mouse(point: Vector2, pressed: bool) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion,true)
	var click := InputEventMouseButton.new()
	click.position = point
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = pressed
	root.push_input(click,true)
func capture(name: String) -> void:
	await process_frame
	await process_frame
	if "--capture" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		var error := root.get_texture().get_image().save_png("res://.local/shared-hud-"+name+".png")
		assert(error == OK)
func run() -> void:
	root.size = Vector2i(1120,800)
	var duel = load("res://scenes/game/main.tscn").instantiate()
	root.add_child(duel)
	duel.set_physics_process(false)
	preload("res://tests/helpers/battle.gd").start(duel,1)
	duel._physics_process(0)
	var weapon_script = duel.hud.get_node("Root/Active0").get_script()
	var slot_script = duel.hud.slots[0][0].get_script()
	var hp_script = duel.hud.get_node("Root/HP1").get_script()
	var action_script = duel.hud.actions[0].get_script()
	assert(duel.hud.get_node("Root/Timer").text == "90 秒")
	assert(not duel.hud.get_node("Root/Active1").visible)
	await capture("duel")
	duel.queue_free()
	await process_frame
	var game = load("res://scenes/game/exploration.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	# A desktop focus notification is not part of this deterministic input fixture.
	game.set_pause_reason("focus",false)
	var hud = game.hud
	var player = game.players[0]
	assert(hud.get_node("Root/Active").get_script() == weapon_script)
	assert(hud.slots[0].get_script() == slot_script)
	assert(hud.get_node("Root/HP").get_script() == hp_script)
	assert(hud.actions[0].get_script() == action_script)
	assert(hud.get_node_or_null("Root/Timer") == null and hud.get_node_or_null("Root/Score") == null)
	player.hurt(2.0)
	player.add_gun(1)
	player.state.shot = 0.0
	player.equip_slot(0)
	game.refresh_hud()
	assert(hud.get_node("Root/HP").recoverable_hp == 1.0)
	assert("反撃回復" in hud.get_node("Root/Health").text)
	# Mutating a view cannot change ammunition or the actor's inventory.
	var view := View.capture(player,true)
	var ammo: int = player.inventory[0].clip
	view.weapons[0].clip = 999
	view.weapons.clear()
	assert(player.inventory.size() == 2 and player.inventory[0].clip == ammo)
	# Shared field changes must dispatch the exploration HUD, not duel refresh arguments.
	var hp_before: float = player.state.hp
	assert(game.switch_field(game.arena.definition).is_empty())
	assert(player.state.hp == hp_before and player.inventory[0].clip == ammo)
	await capture("exploration")
	var point: Vector2 = hud.slots[1].get_global_rect().get_center()
	mouse(point,true)
	mouse(point,false)
	assert(player.state.gun == 1 and not game.mouse_fire_held and player.buffered_fire == 0)
	assert(game.shots.is_empty())
	# Refreshing, opening and closing pause must not refill ammo or reset reload.
	player.weapon().clip = 0
	player.start_reload()
	var reload_before: float = player.state.reload
	player.state.reload = reload_before*.5
	player.state.dodge = .5
	game.refresh_hud()
	assert(hud.get_node("Root/Active/Reload").visible)
	assert(is_equal_approx(hud.get_node("Root/Active/Reload").value,50.0))
	assert(not hud.actions[0].available and not hud.actions[1].available)
	assert(hud.actions[2].available)
	game.mouse_fire_held = true
	player.buffered_fire = .1
	point = hud.get_node("Root/Pause").get_global_rect().get_center()
	mouse(point,true)
	mouse(point,false)
	game.refresh_hud()
	assert(game.paused and not game.mouse_fire_held and player.buffered_fire == 0)
	assert(hud.slots[0].disabled and hud.actions.all(func(action): return not action.available))
	game.set_pause_reason("focus",true)
	game.set_pause_reason("menu",false)
	assert(game.paused)
	game._physics_process(.5)
	assert(player.state.reload == reload_before*.5 and player.weapon().clip == 0)
	# Even a stale/direct request cannot bypass the mode's authority.
	hud.slot_requested.emit(0)
	assert(player.state.gun == 1)
	await capture("paused")
	game.set_pause_reason("focus",false)
	game.refresh_hud()
	assert(player.state.reload == reload_before*.5 and player.weapon().clip == 0)
	assert(not hud.slots[0].disabled)
	for id in range(2,8): player.add_gun(id)
	game.refresh_hud()
	await capture("eight-weapons")
	var dock: Rect2 = hud.get_node("Root/Dock").get_global_rect()
	for slot in hud.slots: assert(slot.visible and dock.encloses(slot.get_global_rect()))
	assert(hud.slots[7].get_global_rect().end.x < hud.actions[0].get_global_rect().position.x)
	root.size = Vector2i(840,600)
	await capture("small")
	root.size = Vector2i(1120,800)
	player.inventory.clear()
	player.state.reload = 0
	game.refresh_hud()
	assert(hud.get_node("Root/Active/Ammo").text == "丸腰")
	assert(hud.slots.all(func(slot): return not slot.visible))
	await capture("unarmed")
	player.state.hp = 0
	game._physics_process(0)
	assert(hud.get_node("Root/Outcome").visible)
	assert(hud.get_node("Root/Pause").disabled)
	assert(hud.actions.all(func(action): return not action.available))
	await capture("result")
	game.queue_free()
	await process_frame
	print("PASS: shared HUD components, isolated views, real input, health/rally, reload, pause authority, eight slots, unarmed and result")
	quit()
