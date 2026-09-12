extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func capture(suffix: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var path := OS.get_environment("CHAMBER_SCREENSHOT")
	if not path.is_empty():
		var target := path.get_basename() + suffix + ".png"
		assert(root.get_texture().get_image().save_png(target) == OK)
func run() -> void:
	var game = load("res://scenes/game/main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.new_match(42)
	game.assign_character(0,5)
	game.match_state._set_products(0,["gun:28","gun:29",21,28,34])
	game.preparation.refresh()
	game.preparation.show_detail("gun:25")
	await capture("-new-starter")
	assert(game.preparation.claim(game.match_state.products[0][2].id))
	var new_relic = game.match_state.builds[0].owned.back()
	assert(game.match_state.place(0,"gun:25",Vector2i.ZERO))
	assert(game.match_state.place(0,new_relic,Vector2i(1,0)))
	game.preparation.refresh()
	game.preparation.show_detail(new_relic)
	await capture("-new-relic")
	game.new_match(42)
	await capture("-preparation")
	var saved_build: Dictionary = game.match_state.builds[0].duplicate(true)
	game.match_state.stage = 5
	game.match_state.builds[0] = {"owned":[],"equipped":[],"positions":{},"mods":{}}
	preload("res://tests/helpers/preparation.gd").rectangle(game.match_state)
	game.preparation.refresh()
	game.preparation.select_expansion("rectangle")
	game.preparation.set_process(false)
	assert(game.preparation.preview_expansion(Vector2i(0,4)))
	await capture("-expansion-valid")
	assert(not game.preparation.preview_expansion(Vector2i(0,0)))
	await capture("-expansion-blocked")
	game.preparation.cancel_placement()
	assert(game.match_state.place_expansion(0,"elbow",Vector2i(4,0)))
	for n in range(20):
		var token := "relic:18:%d" % n
		game.match_state.builds[0].owned.append(token)
		if n < 12: assert(game.match_state.place(0,token,game.match_state.auto_place(0,token)))
	game.preparation.refresh()
	game.preparation.show_detail("relic:18:0")
	await capture("-fine-grid-expanded")
	game.match_state.builds[0] = {"owned":[game.match_state.gun_token(15),0,1,3],"equipped":[],"positions":{},"mods":{}}
	preload("res://tests/helpers/preparation.gd").rectangle(game.match_state)
	assert(game.match_state.place_expansion(0,"rectangle",Vector2i(0,4)))
	assert(game.match_state.place(0,game.match_state.gun_token(15),Vector2i(0,3)))
	for id in [0,1,3]: assert(game.match_state.place(0,id,game.match_state.auto_place(0,id)))
	game.preparation.refresh()
	game.preparation.show_detail(game.match_state.gun_token(15))
	await capture("-planet-nine-cells")
	game.match_state.builds[0] = saved_build
	game.match_state.stage = 1
	game.preparation.cancel_placement()
	game.preparation.refresh()
	game.preparation.show_detail(game.match_state.rewards[0][0],true)
	await capture("-rewards")
	game.match_state.stage = 4
	# P8z：mainは廃止。武器もレリックと同じグリッドに置くので、所持庫に武器を混ぜて自動配置する。
	game.match_state.builds[0] = {"owned":[game.match_state.gun_token(1),0,1,2,3,4,5,6],"equipped":[],"positions":{},"mods":{}}
	preload("res://tests/helpers/preparation.gd").rectangle(game.match_state)
	for entry in game.match_state.builds[0].owned.duplicate(): game.match_state.place(0,entry,game.match_state.auto_place(0,entry))
	game.preparation.refresh()
	await capture("-inventory")
	# B layout: same 7/16-cell example as the accepted design, plus overflow states.
	var prep = game.preparation
	var ms = game.match_state
	var start_gun: String = ms.gun_token(1)
	prep.cancel_placement()
	prep.set_process(false) # Deterministic preview capture, independent of the OS cursor.
	ms.builds[0] = {"owned":[start_gun,2,4,18,3],"equipped":[],"positions":{},"mods":{}}
	preload("res://tests/helpers/preparation.gd").rectangle(ms)
	ms._set_products(0,[1,7,10])
	assert(ms.place(0,start_gun,Vector2i(0,0)))
	assert(ms.place(0,2,Vector2i(2,0)))
	assert(ms.place(0,4,Vector2i(0,2)))
	prep.refresh()
	prep.show_detail(0)
	await capture("-b-layout")
	prep.select_entry(18)
	assert(prep.preview_at(18,Vector2i(3,3)))
	await capture("-b-preview")
	assert(not prep.preview_at(18,Vector2i(0,0)))
	await capture("-b-blocked")
	prep.cancel_placement()
	var mod: Dictionary = game.Weapons.mods_for(1)[0]
	ms.builds[0] = {"owned":[ms.gun_token(9),start_gun,0,1,2,3,4,5],"equipped":[],"positions":{},"mods":{1:mod.key}}
	preload("res://tests/helpers/preparation.gd").rectangle(ms)
	ms._set_products(0,[game.Weapons.mod_token(1,mod.key),6,7,8,9,10])
	prep.refresh()
	prep.show_detail(start_gun)
	await capture("-b-eight-reserve")
	prep.get_node("Root/Panel/Content/Cards/Reserve/Scroll").scroll_horizontal = 10000
	await capture("-b-reserve-end")
	var original_size := root.size
	root.size = Vector2i(1120,800)
	await capture("-b-native-size")
	root.size = original_size
	prep.set_process(true)
	game.new_match(42)
	preload("res://tests/helpers/battle.gd").start(game)
	game.players[0].add_gun(8)
	game.players[1].add_gun(17)
	game._physics_process(.01)
	await capture("-battle")
	game.supplies.reset()
	game.players[0].state.pos = Vector2(140,140)
	game.players[0].sync_visual()
	var pickup = game.supplies.put_item("weapon",4,Vector2(190,140))
	pickup.age = 1.0
	game.supplies.elapsed = 29.9
	game.supplies.step(.11)
	game.hud.refresh(game.players,game.remaining,game.paused,game.result,game.scores,game.phase)
	await capture("-supplies")
	game.supplies.reset()
	game.players[0].add_gun(10) # Explicit combat-render fixture, not a field pickup
	game.players[1].add_gun(9) # Explicit combat-render fixture
	game.players[0].state.pos = Vector2(300,440)
	game.players[1].state.pos = Vector2(660,440)
	game.spawn_well(Vector2(560,440),0)
	game.spawn_shot(1,9,PI,{"pos":Vector2(800,460)})
	game.spawn_shot(0,10,0,{"pos":Vector2(350,440)})
	game._physics_process(.01)
	await capture("-legendary")
	game.players[1].relic_capacity = 6
	assert(game.players[1].acquire_temporary(12))
	game.players[1].sync_visual()
	game.spawn_shot(1,0,0,{"pos":Vector2(730,410),"depth":1,"speed":0.0,"damage":.4})
	game.hud.refresh(game.players,game.remaining,game.paused,game.result,game.scores,game.phase)
	await capture("-p4-danger-temporary")
	game.players[0].relic_capacity = 6
	game.players[0].relics = [0,1,2,3,6,7]
	game.players[1].relics = [12,13,14,15,16,17]
	game.players[1].temporary_relic = 17
	game.players[1].temporary_relic_slot = 5
	game.hud.refresh(game.players,game.remaining,game.paused,game.result,game.scores,game.phase)
	await capture("-relic-cards-six")
	game.hud.toggle_details()
	# The paused grid is laid out after it becomes visible; hover its final position.
	await process_frame
	await process_frame
	var relic_hover := InputEventMouseMotion.new()
	relic_hover.position = game.hud.relic_cards[1][5].get_global_rect().get_center()
	relic_hover.global_position = relic_hover.position
	root.push_input(relic_hover,true)
	# Keep the synthetic hover in place while waiting for the tooltip; a native
	# mouse event when the test window opens can otherwise replace it mid-wait.
	var hover_until := Time.get_ticks_msec() + 700
	while Time.get_ticks_msec() < hover_until:
		await process_frame
		root.push_input(relic_hover,true)
	assert(root.gui_get_hovered_control() == game.hud.relic_cards[1][5])
	await capture("-relic-tooltip")
	game.hud.toggle_details()
	game.use_pulse(1)
	game._physics_process(.12)
	await capture("-pulse")
	game.remaining = 25.0
	game._physics_process(.01)
	await capture("-danger-growing")
	game.remaining = 1.0
	game._physics_process(.01)
	await capture("-danger-max")
	game.reset_round()
	await capture("-danger-reset")
	game.phase = "play"
	game.preparation.refresh()
	for row in range(4):
		game.combat_visuals.weapon_effect(row,Vector2(340+row*145,380))
	game.players[0].hurt(1)
	game.players[1].handle_key(KEY_SHIFT,1,game.shots,game.players[0],game.arena)
	game.hud.refresh(game.players,game.remaining,game.paused,game.result,game.scores,game.phase)
	await capture("-combat-frame0")
	game.combat_visuals.step(.1)
	await capture("-combat-frame1")
	game.combat_visuals.step(.08)
	await capture("-combat-frame2")
	game.reset_round()
	game.phase = "play"
	game.preparation.refresh()
	game.players[0].add_relic(3)
	game.players[0].hurt(1)
	var item = game.supplies.put_item("ammo",0,game.players[1].state.pos)
	item.age = .6
	assert(game.players[1].add_gun(0))
	game.players[1].weapon().reserve = 0
	assert(game.supplies.acquire(1,item))
	game.spawn_shot(0,9,0,{"pos":Vector2(450,400),"life":.001})
	game.spawn_shot(0,10,0,{"pos":Vector2(700,400),"life":.001})
	game._physics_process(.01)
	game._physics_process(.12)
	await capture("-rings-pickup-shake")
	game.reset_round()
	await capture("-shake-reset")
	game.phase = "play"
	game.preparation.refresh()
	game.players[0].set_character(7)
	game.players[0].add_relic(4)
	game.players[0].state.hp = 7.5
	game.players[1].state.hp = 3.2
	for id in [16,17,18,19]:
		game.spawn_shot(0,id,0,{"pos":Vector2(360+(id-16)*140,400),"parcel":id == 17})
	game.hud.refresh(game.players,game.remaining,game.paused,game.result,game.scores,game.phase)
	await capture("-projectile-hp-frame0")
	for shot in game.shots:
		shot.state.age = .17
		shot.step(0.0,game.arena,game.players[1])
	await capture("-projectile-hp-frame2")
	game.reset_round()
	game.phase = "play"
	game.preparation.refresh()
	for p in game.players:
		p.add_relic(0)
		p.add_relic(3)
		p.add_relic(4)
	game.players[0].step(.11,0,game.players[1],game.arena,false,{"dx":1.0,"dy":0.0,"shoot":false,"aim_jitter":0.0})
	game.players[1].handle_key(KEY_SHIFT,1,game.shots,game.players[0],game.arena)
	game.players[1].step(.065,1,game.players[0],game.arena)
	game.hud.refresh(game.players,game.remaining,game.paused,game.result,game.scores,game.phase)
	await capture("-walking-roll")
	game.players[0].step(.11,0,game.players[1],game.arena,false,{"dx":1.0,"dy":0.0,"shoot":false,"aim_jitter":0.0})
	game.players[1].step(.065,1,game.players[0],game.arena)
	await capture("-walking-roll-next")
	for p in game.players:
		p.relic_capacity = 6
		p.relics = [0,1,2,3,4,5]
		p.temporary_relic = 5
		p.temporary_relic_slot = p.relics.find(5)
	game.hud.refresh(game.players,game.remaining,game.paused,game.result,game.scores,game.phase)
	await capture("-six-relics")
	game.players[0].relic_capacity = 22
	game.players[0].relics = []
	for n in range(12): game.players[0].relics.append(18)
	game.players[0].temporary_relic = 18
	game.players[0].temporary_relic_slot = 11
	game.hud.refresh_relics(0,game.players[0])
	game.hud.toggle_details()
	var hud_scroll = game.hud.get_node("Root/Relics/P1/Scroll")
	await process_frame
	await process_frame
	hud_scroll.scroll_vertical = 10000
	await capture("-stacked-hud-scroll")
	assert(hud_scroll.get_global_rect().intersects(game.hud.relic_cards[0][11].get_global_rect()))
	assert(hud_scroll.get_global_rect().end.y <= 800)
	assert("【このラウンドの仮装備】" in game.hud.relic_cards[0][11].tooltip_text)
	game.hud.toggle_details()
	game.new_match(811)
	var clear_hover := InputEventMouseMotion.new()
	clear_hover.position = Vector2(10,10)
	root.push_input(clear_hover,true)
	for i in range(2):
		var starter = game.match_state.reserve_items(i)[0]
		assert(game.match_state.place(i,starter,Vector2i.ZERO))
		assert(game.match_state.confirm(i))
	game.launch_round()
	game.supplies.reset()
	game.players[0].state.pos = Vector2(400,100)
	game.players[0].sync_visual()
	game.hud.refresh(game.players,game.remaining,game.paused,game.result,game.scores,game.phase)
	var stored_chest = game.supplies.put_item("weapon",37,Vector2(400,100))
	stored_chest.age = .6
	stored_chest.refresh(game.players,.6,1.5)
	await capture("-field-reserve-hint")
	game.supplies.interact(0)
	game.supplies.step(1.51)
	assert(not game.players[0].owns(37))
	game.players[1].state.hp = 0
	game._physics_process(.001)
	game.reset_round()
	game.preparation.show_detail("gun:37")
	assert("gun:37" in game.match_state.reserve_items(0))
	await capture("-field-reserve-next-preparation")
	print("PASS: native Compatibility preparation/battle/danger/combat/rings/projectile/HP/player animation frames rendered")
	quit()
