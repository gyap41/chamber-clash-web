extends SceneTree
const AI = preload("res://scripts/ai/cpu_ai.gd")
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var game = load("res://scenes/game/main.tscn").instantiate()
	root.add_child(game)
	preload("res://tests/helpers/battle.gd").passive_opponents(game)
	game.set_physics_process(false)
	preload("res://tests/helpers/battle.gd").start(game)
	game.supplies.reset()
	var cpu = game.players[1]
	var enemy = game.players[0]
	cpu.state.pos = Vector2(560,390)
	enemy.state.pos = Vector2(560,220)
	var chest = game.supplies.put_item("relic",0,Vector2(560,400))
	chest.age = 1.0
	game.spawn_shot(0,0,PI/2,{"pos":Vector2(560,240),"speed":500.0})
	var shot = game.shots.back()
	assert(game.arena.line_blocked(shot.state.pos,cpu.state.pos))
	var ordinary: Dictionary = AI.sample(game,cpu,enemy,.016)
	assert(not ordinary.dodge)
	shot.state.boomerang = true
	cpu.state.ai_cd = 0.0
	cpu.state.dodge = 0.0
	cpu.state.roll = 0.0
	var blade: Dictionary = AI.sample(game,cpu,enemy,.016)
	assert(blade.dodge and not blade.interact)
	assert(cpu.state.ai_loot_pause > 2.0)
	shot.state.dead = true
	var next: Dictionary = AI.sample(game,cpu,enemy,.1)
	assert(not next.interact)
	cpu.state.ai_loot_pause = 0.0
	cpu.state.hp -= 1.0
	assert(not AI.sample(game,cpu,enemy,.1).interact)
	assert(cpu.state.ai_loot_pause == 2.5)
	# A safe pickup on the other side of a wall must be reached via a stable route.
	game.supplies.reset()
	cpu.reset(Vector2(560,220))
	cpu.inventory = [AI.Weapons.new_inventory_entry(0)]
	enemy.state.pos = Vector2(100,500)
	var ammo = game.supplies.put_item("ammo",0,Vector2(560,390))
	ammo.age = 1.0
	cpu.inventory[0].reserve = 0
	var reached := false
	for frame in range(600):
		var decision: Dictionary = AI.sample(game,cpu,enemy,1.0/60.0)
		cpu.step(1.0/60.0,1,enemy,game.arena,false,decision)
		if cpu.state.pos.distance_to(ammo.position) < 30.0:
			reached = true
			break
	assert(reached)
	print("PASS: wall-piercing threat detection, ordinary cover, loot interruption and damage memory")
	game.queue_free()
	quit()
