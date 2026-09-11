extends SceneTree
const AI = preload("res://scripts/ai/cpu_ai.gd")
const Weapons = preload("res://scripts/catalog/weapon_catalog.gd")
func _initialize() -> void:
	call_deferred("run")

func equip(player, id: int) -> void:
	player.inventory = [Weapons.new_inventory_entry(id)]
	player.state.gun = 0
	player.state.ai_combat_path = []
	player.state.ai_path_cd = 0.0

func run() -> void:
	var game = load("res://scenes/game/main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	preload("res://tests/helpers/battle.gd").start(game)
	game.supplies.reset()
	var cpu = game.players[1]
	var enemy = game.players[0]
	game.remaining = game.round_duration
	cpu.state.pos = Vector2(170,280)
	enemy.state.pos = Vector2(170,520)
	equip(cpu,4)
	assert(AI.decide(game,cpu,enemy,1.0/60.0).dy > .9)
	equip(cpu,6)
	assert(AI.decide(game,cpu,enemy,1.0/60.0).dy < -.9)
	equip(cpu,0)
	assert(absf(AI.decide(game,cpu,enemy,1.0/60.0).dy) < .01)
	equip(cpu,18)
	assert(AI.combat_range(cpu) == Vector2(200,340))
	cpu.weapon().mode = 1
	assert(AI.combat_range(cpu) == Vector2(90,170))
	equip(cpu,11)
	var normal: Vector2 = AI.combat_range(cpu)
	cpu.weapon_mods[11] = "wide_sensor"
	assert(AI.combat_range(cpu).y > normal.y)
	# All weapon profiles have a useful, finite band; no split/seed ranged out of reach.
	for id in Weapons.SUPPORTED:
		equip(cpu,id)
		var band: Vector2 = AI.combat_range(cpu)
		assert(band.x >= 0 and band.y > band.x and band.y <= 500)
	# Real player movement must clear each wall from both sides, then reach firing range.
	var cases := [
		[Vector2(560,220),Vector2(560,390)],
		[Vector2(560,390),Vector2(560,220)],
		[Vector2(210,200),Vector2(360,200)],
		[Vector2(360,200),Vector2(210,200)],
		[Vector2(770,400),Vector2(920,400)],
		[Vector2(920,400),Vector2(770,400)],
		[Vector2(170,100),Vector2(950,500)]
	]
	for id in [0,4,6]:
		for pair in cases:
			cpu.reset(pair[0])
			equip(cpu,id)
			enemy.state.pos = pair[1]
			var reached := false
			for frame in range(600):
				var decision: Dictionary = AI.decide(game,cpu,enemy,1.0/60.0)
				cpu.step(1.0/60.0,1,enemy,game.arena,false,decision)
				assert(not game.arena.solid(cpu.state.pos,cpu.radius))
				if AI.Navigation.firing_position(game.arena,cpu.state.pos,enemy.state.pos,AI.combat_range(cpu)):
					reached = true
					break
			assert(reached,"weapon %s route %s stopped at %s" % [id,pair,cpu.state.pos])
	# Moving targets invalidate the old destination; failed searches are rate limited.
	cpu.reset(Vector2(560,220))
	equip(cpu,0)
	enemy.state.pos = Vector2(560,390)
	AI.decide(game,cpu,enemy,.01)
	assert(not cpu.state.ai_combat_path.is_empty())
	enemy.state.pos = Vector2(560,500)
	AI.decide(game,cpu,enemy,.61)
	assert(cpu.state.ai_path_enemy == enemy.state.pos)
	var sealed := Rect2(0,0,1,1)
	var original: Rect2 = game.arena.fighter_bounds
	game.arena.fighter_bounds = sealed
	cpu.state.ai_path_cd = 0.0
	cpu.state.ai_combat_path = []
	AI.decide(game,cpu,enemy,.01)
	assert(cpu.state.ai_combat_path.is_empty())
	AI.decide(game,cpu,enemy,.1)
	assert(is_equal_approx(cpu.state.ai_path_cd,.5))
	game.arena.fighter_bounds = original
	print("PASS: weapon range decisions, switcher/mod profiles, 21 multi-frame wall routes, target movement and unreachable search cooldown")
	game.queue_free()
	quit()
