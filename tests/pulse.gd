extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func key(game, code: int, echo: bool = false) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	event.echo = echo
	game._unhandled_key_input(event)
func run() -> void:
	var game = load("res://scenes/game/main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	var p = game.players[0]
	var q = game.players[1]
	var prep = game.preparation
	assert(p.state.pulses == 2 and not game.use_pulse(0))
	preload("res://tests/helpers/battle.gd").start(game)
	assert(p.state.pulses == 2 and q.state.pulses == 2)
	# Independent combat fixture for consumption and enemy-only removal.
	p.state.pulses = 3
	q.state.pulses = 4
	game.supplies.reset()
	for id in [0,2,9,10,14]:
		game.spawn_shot(1,id,0,{"pos":Vector2(900,100)})
	game.spawn_shot(0,0,0,{"pos":Vector2(100,100)})
	game.spawn_well(Vector2(900,100),1)
	var own_well = game.spawn_well(Vector2(100,100),0)
	# "damage" is now a required field (Starter Cell carries the boosted first-shot damage
	# through an echo's delayed companion shot; see main.gd's delayed_shots handling).
	game.delayed_shots = [{"owner":0,"gun":19,"angle":0.0,"delay":.24,"volley":10,"damage":.5},{"owner":1,"gun":19,"angle":PI,"delay":.24,"volley":11,"damage":.5}]
	p.state.last_volley = 55
	p.state.inv = .1
	p.state.reload = .5
	p.state.reload_slot = p.state.gun
	p.state.roll = .2
	key(game,KEY_Q)
	assert(p.state.pulses == 2 and game.shots.size() == 1 and game.shots[0].state.owner == 0)
	assert(game.wells.size() == 1 and game.wells[0] == own_well)
	assert(game.delayed_shots.size() == 1 and game.delayed_shots[0].owner == 0)
	assert(p.state.inv == .65 and p.state.last_volley == -1 and p.state.reload == .5)
	p.state.roll = 0
	assert(not p.hurt(1,55))
	key(game,KEY_Q,true)
	assert(p.state.pulses == 2)
	game._physics_process(.25)
	assert(game.shots.size() == 2 and game.wells.size() == 1 and game.delayed_shots.is_empty())
	game.paused = true
	var age: float = game.pulse_effects[0].age
	assert(not game.use_pulse(0))
	game._physics_process(.5)
	assert(p.state.inv > 0 and game.pulse_effects[0].age == age)
	game.paused = false
	# P2 pulse reverted to legacy's O (was I); weapon switch reverted to legacy's K (was O).
	var previous: int = q.state.gun
	key(game,KEY_K)
	assert(q.state.gun != previous and q.state.pulses == 4)
	key(game,KEY_O)
	assert(q.state.pulses == 3 and game.shots.is_empty() and game.wells.is_empty())
	p.state.inv = 1.0
	assert(game.use_pulse(0) and p.state.inv == 1.0)
	p.state.pulses = 0
	var count: int = game.pulse_effects.size()
	assert(not game.use_pulse(0) and p.state.pulses == 0 and game.pulse_effects.size() == count)
	game.phase = "result"
	assert(not game.use_pulse(1))
	game.reset_round()
	assert(p.state.pulses == 2 and q.state.pulses == 2 and game.pulse_effects.is_empty())
	print("PASS: initial/reset pulse counts, keys, enemy-only removal, no explosions, invulnerability, repeat/pause/result/empty")
	game.queue_free()
	quit()
