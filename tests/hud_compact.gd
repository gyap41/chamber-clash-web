extends SceneTree
const Art = preload("res://scripts/ui/hud_assets.gd")
func _initialize() -> void:
	call_deferred("run")
func capture(suffix: String) -> void:
	await process_frame
	await process_frame
	if "--hud-screenshot" not in OS.get_cmdline_user_args(): return
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://docs/art/settings/concepts/battle-ui-2026-09-12/implemented-"+suffix+".png") == OK)
func run() -> void:
	root.size = Vector2i(1120,800)
	var game = load("res://scenes/game/main.tscn").instantiate()
	root.add_child(game)
	preload("res://tests/helpers/battle.gd").passive_opponents(game)
	game.set_physics_process(false)
	game.new_match(42)
	game.assign_character(0,0)
	game.assign_character(1,3)
	preload("res://tests/helpers/battle.gd").start(game,1)
	var p = game.players[0]
	var q = game.players[1]
	var hud = game.hud
	q.is_cpu = true
	game.match_state.stage = 4
	game.scores[0] = 2
	game.scores[1] = 1
	game.remaining = 48
	p.state.hp = 6.5
	p.state.dodge = .8
	p.relics = [0,1,3,18,18,14]
	p.temporary_relic = 14
	p.temporary_relic_slot = 5
	p.state.return_battery_armed = true
	p.state.shield = 2.3
	q.relics = [2,4,7]
	p.state.pos = Vector2(300,300)
	q.state.pos = Vector2(800,340)
	p.sync_visual()
	q.sync_visual()
	game._physics_process(0)
	assert(hud.get_node("Root/Round").text == "ROUND 4")
	assert(hud.get_node("Root/Timer").text == "48 秒")
	assert(not hud.get_node("Root/Loadouts/P2").visible)
	assert(not hud.get_node("Root/Active1").visible)
	assert(not hud.get_node("Root/Relics").visible)
	assert(hud.compact_relics[0][0].temporary and hud.compact_relics[0][0].charged)
	assert(hud.compact_relics[0][1].seconds == 3)
	assert(not hud.actions[0].available and hud.actions[2].available)
	for key in ["dodge","melee","pulse"]:
		assert(Art.texture(key) != null)
	for id in range(35): assert(Art.texture("relic_%02d" % id) != null)
	assert(Art.texture("missing_key") == Art.texture("fallback"))
	await capture("cpu")
	for id in range(2,8): p.add_gun(id)
	assert(p.inventory.size() == 8)
	p.relic_capacity = 36
	p.relics = []
	for id in range(35): p.relics.append(id)
	p.relics.append(18)
	p.temporary_relic = 18
	p.temporary_relic_slot = 35
	p.state.hp = 1.5
	p.inventory[p.state.gun].clip = 0
	p.start_reload()
	game._physics_process(0)
	assert(hud.get_node("Root/Active0/Reload").visible)
	assert(not hud.actions[1].available)
	await capture("eight-weapons")
	var dock: Rect2 = hud.get_node("Root/Dock").get_global_rect()
	for slot in hud.slots[0]:
		assert(slot.visible and dock.encloses(slot.get_global_rect()))
	assert(hud.slots[0][7].get_global_rect().end.x < hud.actions[0].get_global_rect().position.x)
	# Details own the pause and cancel held/buffered attacks.
	game.mouse_fire_held = true
	p.buffered_fire = .1
	hud.toggle_details()
	assert(game.paused and not game.mouse_fire_held and p.buffered_fire == 0)
	assert(hud.get_node("Root/Relics").visible)
	var before: float = game.remaining
	game._physics_process(.5)
	assert(game.remaining == before)
	assert(not game.use_pulse(0))
	assert(hud.relic_cards[0][35].temporary)
	assert("同種2個" in hud.relic_cards[0][35].tooltip_text)
	await capture("relics")
	var motion := InputEventMouseMotion.new()
	motion.position = hud.relic_cards[0][0].get_global_rect().get_center()
	root.push_input(motion,true)
	assert(root.gui_get_hovered_control() == hud.relic_cards[0][0])
	var scroll = hud.get_node("Root/Relics/P1/Scroll")
	scroll.scroll_vertical = 10000
	await capture("relics-scroll")
	assert(scroll.get_global_rect().intersects(hud.relic_cards[0][35].get_global_rect()))
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	game._unhandled_key_input(escape)
	game._physics_process(0)
	assert(not game.paused and not hud.get_node("Root/Relics").visible and not game.mouse_fire_held)
	q.is_cpu = false
	game._physics_process(0)
	await capture("local")
	assert(not hud.get_node("Root/Loadouts/P2").visible and not hud.get_node("Root/Active1").visible)
	for row in hud.slots:
		for slot in row:
			if slot.visible: assert(dock.encloses(slot.get_global_rect()))
	assert(not hud.slots[1][0].disabled)
	# Verify transformed camera coordinates, not a changed fighter simulation.
	game.arena.get_node("CombatCamera").force_update_scroll()
	var transform: Transform2D = game.arena.get_canvas_transform()
	assert((transform * Vector2(0,0)).is_equal_approx(Vector2(0,90)))
	assert(game.arena.fighter_bounds == Rect2(60,82,1000,458))
	q.is_cpu = true
	p.inventory.clear()
	p.relics.clear()
	p.state.reload = 0
	game._physics_process(0)
	assert(hud.get_node("Root/Active0/Ammo").text == "丸腰")
	assert(hud.relic_cards[0].all(func(card): return not card.visible))
	assert(hud.slots[0].all(func(slot): return not slot.visible))
	await capture("empty")
	# Real smaller window rendering retains the logical layout via canvas_items.
	root.size = Vector2i(840,600)
	await capture("small")
	game.result = "P1 WINS"
	game.scores[0] = 5
	game._physics_process(0)
	assert(hud.get_node("Root/ResultActions/Title").visible)
	assert(not hud.get_node("Root/Relics").visible)
	await capture("result")
	print("PASS: compact HUD CPU/local, eight weapons, 36 relics, pause/ESC/input guards, reload/abilities, fallback art, camera presentation, empty loadout")
	game.queue_free()
	await process_frame
	quit()
