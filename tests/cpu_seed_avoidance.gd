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
	cpu.state.pos = Vector2(170,300)
	enemy.state.pos = Vector2(170,520)
	cpu.state.ai_cd = 0.0
	game.remaining = game.round_duration
	game.spawn_shot(0,35,0.0,{"pos":Vector2(260,300)})
	var flower = game.shots.back()
	flower.state.age = .7
	flower.state.velocity = Vector2.ZERO
	var chest = game.supplies.put_item("relic",0,Vector2(190,300))
	chest.age = 1.0
	var warning: Dictionary = AI.sample(game,cpu,enemy,.016)
	assert(warning.dx < 0 and not warning.interact and not warning.dodge)
	assert(cpu.state.ai_loot_pause > 2.0)
	# Already inside the 80px sensor: roll away, respecting the real cooldown.
	flower.state.pos = Vector2(240,300)
	var inside: Dictionary = AI.sample(game,cpu,enemy,.016)
	assert(inside.dx < 0 and inside.dodge)
	cpu.state.dodge = 1.0
	assert(not AI.sample(game,cpu,enemy,.016).dodge)
	# The actual projectile transition is then handled as an incoming moving bullet.
	flower.step(.016,game.arena,[cpu])
	assert(flower.state.launched and flower.state.velocity.length() > 0)
	cpu.state.dodge = 0.0
	cpu.state.ai_cd = 0.0
	assert(AI.sample(game,cpu,enemy,.016).dodge)
	# Sensor does not work through cover, and friendly/dead flowers are ignored.
	cpu.state.pos = Vector2(500,280)
	enemy.state.pos = Vector2(500,500)
	flower.state.pos = Vector2(540,238)
	flower.state.launched = false
	flower.state.velocity = Vector2.ZERO
	cpu.state.ai_cd = 0.0
	cpu.state.ai_loot_pause = 0.0
	assert(game.arena.line_blocked(cpu.state.pos,flower.state.pos))
	assert(cpu.state.pos.distance_to(flower.state.pos) < 80.0)
	assert(not AI.sample(game,cpu,enemy,.016).dodge)
	assert(cpu.state.ai_loot_pause == 0.0)
	flower.state.pos = cpu.state.pos+Vector2(50,0)
	flower.state.owner = 1
	assert(not AI.sample(game,cpu,enemy,.016).dodge)
	flower.state.owner = 0
	flower.state.dead = true
	assert(not AI.sample(game,cpu,enemy,.016).dodge)
	print("PASS: Bellflower sensor warning, loot suppression, escape/roll cooldown, real launch, cover and friendly/dead exclusions")
	game.queue_free()
	quit()
