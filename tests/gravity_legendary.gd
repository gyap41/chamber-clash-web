extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var game=load("res://scenes/game/main.tscn").instantiate();root.add_child(game)
	game.set_physics_process(false)
	preload("res://tests/helpers/battle.gd").passive_opponents(game)
	preload("res://tests/helpers/battle.gd").start(game,10)
	var a=game.spawn_well(Vector2(440,300),0);var b=game.spawn_well(Vector2(550,300),1)
	var va=a.get_node("LegendaryVisual");var vb=b.get_node("LegendaryVisual")
	assert(va.lens_material!=vb.lens_material)
	assert(va.emitters.size()==2 and va.emitters[0].amount+va.emitters[1].amount==124)
	for emitter in va.emitters:assert(emitter is CPUParticles2D and emitter.speed_scale==0)
	game._physics_process(.1)
	var age:float=va.effect_age;var clock:float=va.simulated_time
	game.paused=true;game._physics_process(.5)
	await process_frame;await process_frame
	assert(va.effect_age==age and va.simulated_time==clock)
	assert(is_equal_approx(va.lens_material.get_shader_parameter("effect_age"),age))
	game.paused=false;game.result="DRAW";game._physics_process(.5)
	assert(va.simulated_time==clock)
	game.result="";game._physics_process(.1)
	assert(va.simulated_time>clock)
	game.reset_round();await process_frame
	assert(not is_instance_valid(va) and not is_instance_valid(vb))
	assert(game.wells.is_empty())
	print("PASS: native particles use combat clock, independent lens materials, pause/result and cleanup")
	game.queue_free();quit()
