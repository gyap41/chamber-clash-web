extends SceneTree
const V = preload("res://scripts/catalog/weapon_visual_catalog.gd")
var events: Array = []
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var game = load("res://scenes/game/main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	preload("res://tests/helpers/battle.gd").passive_opponents(game)
	preload("res://tests/helpers/battle.gd").start(game,0)
	var p = game.players[0]
	game.presentation.emitted.connect(func(kind,args):
		if kind == "weapon_event": events.append(args[0].duplicate()))
	# Profiles are detached, named, and have defaults without changing combat definitions.
	var custom := V.profile(0);custom.color = "#000000"
	assert(V.profile(0).color != custom.color and not V.profile(999).is_empty())
	assert(V.texture("res://missing-optional-visual.png") != null)
	# Reload completion fires once, from the actual operation, and cancellation wins.
	p.weapon().clip = 0
	p.start_reload()
	var token: int = p.reload_visual_token
	assert(events.back().kind == "reload_start" and p.get_node("Animation").reload_event.token == token)
	p.finish_reload();p.finish_reload()
	assert(events.filter(func(e): return e.kind == "reload_complete" and e.token == token).size()==1)
	assert(p.get_node("Animation").reload_event.is_empty())
	p.state.reload = 0;p.weapon().clip = 0
	p.start_reload();token = p.reload_visual_token
	p.add_gun(6)
	assert(events.back().kind == "reload_cancel" and events.back().token == token)
	assert(p.get_node("Animation").reload_event.is_empty())
	p.weapon().clip = 0;p.state.reload = 0;p.start_reload()
	p.state.inv = 0;p.hurt(100)
	assert(not p.reload_visual_active and p.get_node("Animation").reload_event.is_empty())
	# A split keeps gameplay ID 0 but carries source-specific appearance.
	game.reset_round();game.phase = "play";events.clear()
	game.spawn_shot(0,2,0,{"life":.001,"pos":Vector2(400,100)})
	game.combat._step_projectiles(.01)
	assert(game.shots.size()==8)
	for b in game.shots:
		assert(b.gun_id==0 and b.visual_id==2 and b.visual_variant=="firework_shard")
	# Natural expiry of an ordinary bullet is not an impact; explicit removal is silent.
	game.clear_field_objects();events.clear()
	game.spawn_shot(0,0,0,{"life":.001,"pos":Vector2(400,100)})
	game.combat._step_projectiles(.01)
	assert(events.size()==1 and events[0].kind=="expire")
	assert(not game.combat_visuals.named_effects.any(func(e): return e.kind=="hit"))
	events.clear();game.spawn_shot(0,9,0);game.shots.back().state.dead=true
	game.combat._step_projectiles(.01)
	assert(events.is_empty() and game.shots.is_empty())
	# Delayed fire retains its weapon after a switch; no simulation input is read from VFX.
	game.reset_round();game.phase="play";events.clear()
	p.add_gun(19);p.state.shot=0;game.fire(0)
	p.add_gun(6);events.clear()
	game.combat._step_delayed_shots(.25)
	assert(events.any(func(e): return e.kind=="fire" and e.weapon==19))
	assert(not events.any(func(e): return e.kind=="fire" and e.weapon==6))
	# A custom visual scene has the same bounded manual clock/cleanup contract.
	var fx = game.combat_visuals
	fx.clear()
	V.data.effects["probe"]={"scene":"res://tests/fixtures/weapon_effect_probe.tscn","duration":.1}
	V.data.weapons["0"]["hit"]="probe"
	fx.weapon_event({"kind":"hit","weapon":0,"pos":Vector2.ZERO})
	assert(fx.custom_effects.size()==1)
	fx.step(.05);assert(is_equal_approx(fx.custom_effects[0].age,.05))
	fx.step(.06);assert(fx.custom_effects.is_empty())
	V.data.weapons["0"]["reload_start"]="probe"
	fx.weapon_event({"kind":"reload_start","weapon":0,"owner":"p0","token":80,"duration":1.0})
	fx.weapon_event({"kind":"reload_cancel","weapon":0,"owner":"p0","token":79})
	assert(fx.custom_effects.size()==1)
	fx.weapon_event({"kind":"reload_cancel","weapon":0,"owner":"p0","token":80})
	assert(fx.custom_effects.is_empty())
	V.data.weapons["0"].erase("hit");V.data.weapons["0"].erase("reload_start");V.data.effects.erase("probe")
	# Gameplay hooks are explicitly registered in the gameplay catalog, not art settings.
	var catalog = preload("res://scripts/catalog/game_catalog.gd")
	catalog.data.guns[0]["behaviors"]=["res://tests/fixtures/weapon_behavior_probe.gd"]
	game.spawn_shot(0,0,0)
	assert(game.shots.back().state.get("probe_launch",false))
	assert(p.get_meta("probe_event")==&"launch")
	catalog.data.guns[0].erase("behaviors")
	print("PASS: visual profile defaults, reload lifecycle, source-aware fragments, expiry/removal, delayed weapon identity")
	game.queue_free();quit()
