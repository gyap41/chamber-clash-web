extends SceneTree
const View = preload("res://scripts/ui/combat_hud_view.gd")
var game
func _initialize() -> void:
	call_deferred("run")
func capture(label: String) -> void:
	await process_frame
	await process_frame
	if "--capture" not in OS.get_cmdline_user_args(): return
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://.local/hud-a-"+label+".png") == OK)
func run() -> void:
	root.size = Vector2i(1120,800)
	game = load("res://scenes/game/exploration.tscn").instantiate()
	game.random_floor = true
	game.authored_campaign = true
	root.add_child(game)
	game.set_physics_process(false)
	game.set_pause_reason("focus",false)
	var player = game.players[0]
	var hud = game.hud
	player.state.hp = 3.2
	game.exploration.inventory.gold[0] = 28
	game.refresh_hud()
	assert(hud.get_node("Root/HP").current_hp == 3.2)
	assert(not hud.get_node("Root/Health").visible and "3.2" in hud.get_node("Root/HP").tooltip_text)
	assert(not hud.get_node("Root/Status").visible and not hud.get_node("Root/Name").visible)
	assert(hud.get_node("Root/Gold").text == "28")
	assert(hud.actions[2].charges == player.state.pulses)
	assert(not root.get_node("Music").toggle.visible)
	assert(hud.get_node("Root/Active/Name").visible == false and not hud.get_node("Root/Active/State").visible)
	assert(hud.actions.all(func(a): return not a.get_node("Key").visible and not a.get_node("State").visible))
	assert(hud.actions.all(func(a): return not a.tooltip_text.is_empty() and a.mouse_filter != Control.MOUSE_FILTER_IGNORE))
	var action = hud.actions[1]
	action.refresh(.4,.8,false,"近接")
	action.refresh(0,.8,true,"近接")
	assert(action.ready_flash > 0)
	action._process(.5)
	assert(action.ready_flash == 0)
	await capture("normal")
	game.toggle_pause()
	game.refresh_hud()
	assert(hud.get_node("Root/PauseMenu").visible and hud.get_node("Root/Music").visible)
	var music = root.get_node("Music")
	var enabled: bool = music.enabled
	hud.get_node("Root/Music").pressed.emit()
	assert(music.enabled != enabled)
	hud.get_node("Root/Music").pressed.emit()
	assert(music.enabled == enabled)
	await capture("pause")
	game.toggle_pause()
	game.refresh_hud()
	assert(not hud.get_node("Root/Sound").visible and not hud.get_node("Root/Title").visible)
	assert(game.open_bag())
	assert(not hud.get_node("Root/PauseMenu").visible)
	game.close_bag()
	for id in range(7): player.add_gun(id)
	player.weapon().clip = 0
	player.start_reload()
	game.refresh_hud()
	assert(hud.get_node("Root/Active/Reload").visible)
	assert(hud.get_node("Root/Loadout").get_global_rect().position.x >= 396)
	assert(hud.get_node("Root/Loadout").get_global_rect().end.x < 802)
	await capture("eight-reload")
	var view: Dictionary = View.capture(player,true)
	var mode: Dictionary = {"paused":false,"result":"","sound_enabled":true,"door_hint":"敵を全滅させると出口が開きます","encounter_active":true,"enemies_alive":1,"gold":28,"map_available":true,"boss":{"hp":36,"max_hp":72,"intro":false,"second":true}}
	hud.present(view,mode)
	assert(hud.get_node("Root/Help").text.is_empty())
	var boss: Control = hud.get_node("Root/BossHP")
	assert(boss.visible and not boss.get_global_rect().intersects(hud.get_node("Root/HP").get_global_rect()))
	assert(not boss.get_global_rect().intersects(hud.get_node("Root/Map").get_global_rect()))
	await capture("boss-layout")
	root.size = Vector2i(840,600)
	await capture("small")
	game.queue_free()
	await process_frame
	print("PASS: A HUD health precision, hidden redundant labels, pause settings, overlay separation, eight guns/reload and boss clearance")
	quit()
