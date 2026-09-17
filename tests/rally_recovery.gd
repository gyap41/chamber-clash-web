extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var game = load("res://scenes/game/main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	preload("res://tests/helpers/battle.gd").passive_opponents(game)
	preload("res://tests/helpers/battle.gd").start(game)
	var p = game.players[0]
	var q = game.players[1]
	p.reset(Vector2(350,450))
	q.reset(Vector2(390,450))
	var maximum: float = p.state.hp
	assert(p.hurt(2))
	assert(is_equal_approx(p.rally_available(),1.0))
	# Only actual damage counts, with fractional recovery and no overkill credit.
	assert(q.hurt(.4,-1,false,{},p))
	assert(is_equal_approx(p.state.hp,maximum-1.6))
	assert(is_equal_approx(p.rally_available(),.6))
	assert(not q.hurt(2,-1,false,{},p))
	assert(is_equal_approx(p.rally_available(),.6))
	q.state.inv = 0.0
	q.state.hp = .2
	assert(q.hurt(20,-1,false,{},p))
	assert(is_equal_approx(p.state.hp,maximum-1.4))
	assert(is_equal_approx(p.rally_available(),.4))
	assert(q.rally_available() == 0)
	# Independent wound expiry; no passive healing.
	p.advance_rally(2.5)
	p.state.inv = 0.0
	p.hurt(2)
	p.advance_rally(.51)
	assert(is_equal_approx(p.rally_available(),1.0))
	var before: float = p.state.hp
	p.advance_rally(2.5)
	assert(p.rally_available() == 0 and p.state.hp == before)
	p.state.inv = 0.0
	p.hurt(.5,-1,true)
	assert(p.rally_available() == 0)
	# Projectiles credit their source even after the source changes weapons.
	p.reset(Vector2(350,450))
	q.reset(Vector2(390,450))
	p.hurt(2)
	p.add_gun(0)
	p.add_gun(4)
	game.spawn_shot(0,0,0,{"pos":q.state.pos,"damage":.5})
	game.shots.back().step(.001,game.arena,q)
	assert(is_equal_approx(p.rally_available(),.5))
	# Melee shares the same accounting.
	q.state.inv = 0.0
	p.state.angle = 0.0
	p.try_melee(0,[],q,game.arena)
	assert(p.rally_available() == 0)
	# Gravity ticks credit the owner, including a dead owner's no-resurrection rule.
	p.state.inv = 0.0
	p.hurt(2)
	q.state.inv = 0.0
	var well = game.spawn_well(q.state.pos,0)
	well.step(.01,game.arena,game.players,[],game.roster)
	assert(is_equal_approx(p.rally_available(),.35))
	p.state.inv = 0.0
	p.hurt(100)
	q.state.inv = 0.0
	q.hurt(.1,-1,false,{},p)
	assert(p.state.hp == 0 and p.rally_available() == 0)
	# Expiring comet blast routes damage to its owner, independently of its shards.
	p.reset(Vector2(350,450))
	q.reset(Vector2(390,450))
	p.hurt(2)
	game.spawn_shot(0,9,0,{"pos":q.state.pos,"life":.001})
	game.shots.back().state.life = 0.0
	game.combat._step_projectiles(0.0)
	assert(p.rally_available() == 0)
	# Round reset clears pending recovery; HUD exposes recoverable HP separately.
	p.reset(Vector2(350,450))
	p.hurt(2)
	game.hud.refresh(game.players,90.0,false,"",game.scores,"play")
	assert(is_equal_approx(game.hud.get_node("Root/HP1").recoverable_hp,1.0))
	assert("反撃回復" in game.hud.get_node("Root/Health0").text)
	if "--capture" in OS.get_cmdline_user_args():
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		get_root().get_texture().get_image().save_png("res://.local/rally-recovery.png")
	p.reset(Vector2(350,450))
	assert(p.rally_available() == 0)
	# Guarded hits grant neither actor recovery; partial armor uses reduced damage.
	q.reset(Vector2(390,450))
	p.hurt(2)
	q.relics = [3]
	assert(not q.hurt(2,-1,false,{},p))
	assert(q.rally_available() == 0 and is_equal_approx(p.rally_available(),1.0))
	q.relics = [27]
	q.state.inv = 0.0
	q.state.shell_time = 1.0
	q.hurt(1.0,42,false,{},p)
	assert(is_equal_approx(p.rally_available(),.5) and is_equal_approx(q.rally_available(),.25))
	# Other healing discards excess recovery instead of banking it for later damage.
	p.state.hp = p.state.max_hp
	p.trim_rally()
	assert(p.rally_wounds.is_empty())
	print("PASS: rally fraction/expiry/overkill/immunity/hazard/death/reset, projectile/melee/gravity/blast attribution and HUD")
	game.queue_free()
	await process_frame
	quit()
