extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var rig = preload("res://scripts/visuals/twohead_rina.gd")
	# Foot roles swap exactly after half a cycle; fixed UVs keep the body stable.
	for phase in [0.0, .5, 1.0, 2.0]:
		assert(rig.shoe_offset(phase,0,Vector2.DOWN).is_equal_approx(rig.shoe_offset(phase+3,1,Vector2.DOWN)))
	assert(rig.shoe_offset(0,0,Vector2.DOWN).y > rig.shoe_offset(0,1,Vector2.DOWN).y)
	assert(rig.shoe_offset(3,0,Vector2.DOWN).y < rig.shoe_offset(3,1,Vector2.DOWN).y)
	var game = load("res://scenes/game/main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	preload("res://tests/helpers/battle.gd").passive_opponents(game)
	game.assign_character(0,0)
	preload("res://tests/helpers/battle.gd").start(game,20)
	var p = game.players[0]
	var q = game.players[1]
	var anim = p.get_node("Animation")
	p.state.pos = Vector2(360,420)
	p.state.angle = 0.0
	p.sync_visual()
	var source_transform: Transform2D = p.get_node("Sprite").transform
	var old_pos: Vector2 = p.state.pos
	p.step(.1,0,q,game.arena,false,{"dx":1.0,"dy":0.0,"shoot":false,"aim_jitter":0.0})
	assert(is_equal_approx(p.state.pos.x-old_pos.x,20.5))
	assert(anim.animation_name == "move")
	var clip: int = p.weapon().clip
	game.fire(0)
	assert(p.weapon().clip == clip-1 and anim.muzzle > 0)
	assert(game.shots.back().get_node("Art").visible)
	assert(not game.shots.back().get_node("Visual").visible)
	game.spawn_shot(0,20,0,{"pos":Vector2(1086,100)})
	game.shots.back().step(.02,game.arena,q)
	assert(game.combat_visuals.named_effects.any(func(e): return e.kind == "hit" and e.weapon == 20))
	p.start_reload()
	assert(p.state.reload > 0)
	var reload_time: float = p.state.reload
	p.step(reload_time*.5,0,q,game.arena,false,{"dx":0.0,"dy":0.0,"shoot":false,"aim_jitter":0.0})
	assert(p.state.reload > 0 and p.weapon().clip == clip-1)
	p.step(reload_time*.5+.001,0,q,game.arena,false,{"dx":0.0,"dy":0.0,"shoot":false,"aim_jitter":0.0})
	assert(p.state.reload == 0 and p.weapon().clip == clip)
	p.state.dir = Vector2.LEFT
	p.state.angle = 0.0 # Aim right, roll left: body must follow travel.
	p.try_dodge()
	assert(is_equal_approx(p.state.roll,.38) and is_equal_approx(p.state.inv,.31))
	for i in range(6):
		p.state.roll = .38*(1.0-(i+.1)/6.0)
		p.sync_visual()
		assert(anim.animation_name == "roll" and anim.animation_frame == i)
		assert(is_equal_approx(anim.pose.get_rotation(),0.0))
		assert(anim.body_facing == -1)
		assert(not p.get_node("Weapon").visible)
	p.state.roll = .01
	p.state.inv = .06
	p.step(.01,0,q,game.arena,false,{"dx":0.0,"dy":0.0,"shoot":false,"aim_jitter":0.0})
	assert(p.state.roll == 0 and is_equal_approx(p.state.inv,.05))
	assert(p.get_node("Weapon").visible and anim.animation_name == "idle")
	assert(p.get_node("Sprite").transform == source_transform)
	assert(p.dodge_duration == .38 and p.roll_speed == 590 and p.radius == 14)
	# Up/down aim uses back/front art; small horizontal jitter preserves the row.
	anim.moving = false
	p.state.angle = -PI/2
	p.sync_visual()
	assert(anim.body_back and p.get_node("Weapon").z_index == -1)
	p.state.angle = -.05
	p.sync_visual()
	assert(not anim.body_back and anim.body_view == "right")
	p.state.angle = PI/2
	p.sync_visual()
	assert(not anim.body_back and p.get_node("Weapon").z_index == 1)
	var grip: Vector2 = p.get_node("Weapon").position
	p.sync_visual()
	assert(p.get_node("Weapon").position.is_equal_approx(grip))
	# Moving away from aim reverses the stride, while a roll follows travel.
	p.state.angle = 0.0
	p.state.dir = Vector2.LEFT
	anim.moving = true
	anim.move_phase = 1.0
	p.sync_visual()
	assert(anim.animation_frame == 5 and anim.body_facing == 1)
	anim.moving = false
	p.state.dir = Vector2.UP
	p.state.roll = .13
	p.sync_visual()
	assert(anim.body_back and not p.get_node("Weapon").visible)
	p.state.roll = 0.0
	p.state.angle = 0.3
	p.sync_visual()
	p.weapon().reserve = 0
	var ammo = game.supplies.put_item("ammo",0,p.state.pos)
	assert(ammo.get_node("ChestArt").visible and not ammo.get_node("Frame").visible)
	ammo.age = 1.0
	assert(game.supplies.acquire(0,ammo))
	assert(p.weapon().reserve > 0)
	assert(game.arena.get_node("CombatCamera").position == Vector2(0,-90))
	assert(game.arena.get_node("Walls").get_child_count() == 3)
	print("PASS: Workshop movement/fire/reload/resupply, dive phases, travel-facing, .38/.31 Rina timing and unchanged geometry")
	game.queue_free()
	quit()
