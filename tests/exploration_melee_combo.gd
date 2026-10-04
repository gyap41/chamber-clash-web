extends SceneTree
const Registry = preload("res://scripts/catalog/enemy_registry.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var game = load("res://scenes/game/combat_lab.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	for id in Registry.ENEMIES:
		assert(game.launch_test("courtyard",[id],20))
		var p = game.players[0]
		var enemy = game.players[1]
		p.reset(Vector2(400,350))
		p.state.angle = 0
		enemy.prepare(Vector2(440,350))
		enemy.state.hp = 20
		enemy.state.max_hp = 20
		var events: Array = []
		var listener = func(event):
			if event.kind == "melee_hit": events.append(event)
		p.weapon_event_requested.connect(listener)
		assert(enemy.hurt(.55,100,false,{},p))
		p.try_melee(0,[],enemy,game.arena)
		assert(is_equal_approx(enemy.state.hp,18.85),"Projectile then melee must both land: "+id)
		assert(events.size()==1 and enemy.melee_push_time>0)
		p.resolve_melee_hits(0,[],enemy,game.arena)
		assert(is_equal_approx(enemy.state.hp,18.85) and events.size()==1)
		assert(enemy.hurt(.55,100,false,{},p),"Same-volley pellets remain valid")
		assert(not enemy.hurt(.55,101,false,{},p),"Other volleys still respect bullet immunity")
		assert(not enemy.hurt(.6,-1,false,{"kind":"melee"},p))
		enemy.move_with_command(.23,1,p,game.arena,{"dx":0.0,"dy":0.0,"angle":0.0,"shoot":false})
		assert(enemy.hurt(.6,-1,false,{"kind":"melee"},p),"Melee window expires with combat time")
		assert(enemy.enemy_visual_snapshot().hit>0,"Melee still flashes")
		assert(enemy.hurt(.55,102,false,{},p),"Melee does not consume projectile window")
		enemy.melee_damage_window=0.0
		enemy.state.inv=1.0
		assert(not enemy.hurt(.6,-1,false,{"kind":"melee"},p))
		enemy.prepare(Vector2(440,350))
		assert(enemy.melee_damage_window==0)
		enemy.state.inv=.22
		enemy.state.last_volley=-1
		assert(not enemy.hurt(.6,-1,false,{"kind":"melee"},p),"Unclassified immunity remains protected")
		p.weapon_event_requested.disconnect(listener)
		await process_frame
	# The boss keeps its shared damage window; player immunity is unchanged too.
	var enemy = game.players[1]
	enemy.spec=enemy.spec.duplicate()
	enemy.spec.id="furnace_warden"
	enemy.prepare(Vector2(440,350))
	assert(enemy.hurt(.1,200))
	assert(not enemy.hurt(.6,-1,false,{"kind":"melee"}))
	var p = game.players[0]
	p.reset(Vector2(400,350))
	assert(p.hurt(.1,201))
	assert(not p.hurt(.6,-1,false,{"kind":"melee"}))
	game.queue_free()
	await process_frame
	print("PASS: all exploration enemies gun/melee windows, single-swing hit/feedback, pellets, expiry, reset, protected immunity, boss/player policy")
	quit()
