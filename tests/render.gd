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
	await capture("-preparation")
	game.match_state.stage = 4
	game.match_state.builds[0] = {"main":1,"owned":[0,1,2,3,4,5,6,7],"equipped":[0,1,2,3,4,5]}
	game.preparation.refresh()
	await capture("-inventory")
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
	game.players[0].acquire_weapon(10,true)
	game.players[1].acquire_weapon(9,true)
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
	game.hud.refresh(game.players,game.remaining,game.paused,game.result,game.scores,game.phase)
	await capture("-relic-cards-six")
	var relic_hover := InputEventMouseMotion.new()
	relic_hover.position = game.hud.relic_cards[1][5].get_global_rect().get_center()
	relic_hover.global_position = relic_hover.position
	root.push_input(relic_hover,true)
	await create_timer(.7).timeout
	assert(root.gui_get_hovered_control() == game.hud.relic_cards[1][5])
	await capture("-relic-tooltip")
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
	game.players[1].weapon().reserve = 0
	game.supplies.acquire(1,item)
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
	game.hud.refresh(game.players,game.remaining,game.paused,game.result,game.scores,game.phase)
	await capture("-six-relics")
	print("PASS: native Compatibility preparation/battle/danger/combat/rings/projectile/HP/player animation frames rendered")
	quit()
