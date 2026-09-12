extends SceneTree
const Command = preload("res://scripts/combat/combat_command.gd")
const Inventory = preload("res://scripts/game/run_inventory.gd")
func _initialize() -> void: call_deferred("run")
func fixture():
	var game = load("res://scenes/game/main.tscn").instantiate()
	var original = game.get_node("Arena")
	game.remove_child(original)
	original.free()
	var field = load("res://scenes/world/arena_validation.tscn").instantiate()
	field.name = "Arena"
	game.add_child(field)
	game.participant_config = [
		{"id":"hero-42","team":"solo","controller":"external"},
		{"id":"bot-17","team":"opponents","controller":"cpu"},
		{"id":"bot-99","team":"opponents","controller":"cpu"},
		{"id":"bot-6","team":"opponents","controller":"cpu"}]
	root.add_child(game)
	game.set_physics_process(false)
	game.command_source = func(i,dt): return game.CpuAI.sample(game,game.players[i],game.roster.nearest(i,game.players,game.players[i].state.pos),dt)
	for i in range(game.players.size()): game.preparation.auto_prepare(i)
	game.launch_round()
	assert(game.phase == "play")
	return game
func fresh(game) -> void:
	game.new_match(902)
	for i in range(game.players.size()):
		game.match_state.place(i,"gun:0",Vector2i.ZERO)
		game.match_state.confirm(i)
	game.launch_round()
	game.supplies.reset()
	game.command_source = func(i,_dt): return Command.idle(game.players[i].state.angle)
	for i in range(game.players.size()): game.players[i].state.pos = Vector2(180+i*250,120)
func run() -> void:
	var game = fixture()
	if "--extension-preview" in OS.get_cmdline_user_args():
		game.roster.participants[0].controller = "human"
		game.command_source = game.resolve_command
		game.set_physics_process(true)
		return
	assert(game.players.size() == 4 and game.match_state.builds.size() == 4)
	assert(game.arena.field_rect.size == Vector2(1440,900))
	for i in range(4):
		assert(game.players[i].state.pos == game.arena.spawn_position(i))
		assert(not game.arena.solid(game.players[i].state.pos,14))
	assert(game.roster.nearest(2,game.players,game.players[2].state.pos) == game.players[0])
	assert(game.roster.enemies(0,game.players).size() == 3)
	# Real 1-v-3 CPU simulation on the second field, with no presentation subscriber.
	game.presentation.emitted.disconnect(game._present_event)
	var starts: Array = game.players.map(func(p): return p.state.pos)
	for frame in range(600):
		game.combat.step(1.0/60.0)
		game._settle_round()
		if game.phase == "result": break
	for i in range(4):
		assert(game.players[i].state.pos != starts[i])
		assert(game.arena.fighter_bounds.has_point(game.players[i].state.pos))
	# Passive fixtures below use the same authority service and deterministic commands.
	fresh(game)
	var p = game.players[0]
	var ally = game.players[2]
	var target = game.players[3]
	assert(not game.roster.hostile(1,2) and game.roster.hostile(0,2))
	game.players[1].state.pos = Vector2(200,120)
	ally.state.pos = Vector2(250,120)
	target.state.pos = Vector2(290,120)
	p.state.pos = Vector2(330,120)
	game.spawn_shot(1,0,0,{"pos":Vector2(220,120),"speed":420.0})
	game._step_projectiles(.3)
	assert(ally.state.hp == ally.state.max_hp and target.state.hp == target.state.max_hp)
	assert(p.state.hp < p.state.max_hp) # It passed two teammates before the enemy.
	# One integration per tick even when the shooter has three enemies.
	game.spawn_shot(0,0,0,{"pos":Vector2(180,750),"speed":100.0})
	var bullet = game.shots.back()
	game._step_projectiles(.1)
	assert(bullet.state.pos.is_equal_approx(Vector2(190,750)))
	# Multi-target melee and explosion each hit all hostile actors in range.
	fresh(game)
	p.state.pos = Vector2(180,120)
	for i in range(1,4): game.players[i].state.pos = Vector2(215,110+i*5)
	game.apply_command(0,{"melee":true,"angle":0.0})
	for i in range(1,4): assert(game.players[i].state.hp < game.players[i].state.max_hp)
	for i in range(1,4): game.players[i].state.inv = 0
	game.spawn_shot(0,9,0,{"pos":Vector2(215,120),"life":0.0})
	game._step_projectiles(.01)
	for i in range(1,4): assert(game.players[i].state.hp < game.players[i].state.max_hp-1.0)
	# Friendly pulse keeps allies' immediate and delayed projectiles and gravity wells.
	fresh(game)
	for i in range(4):
		game.spawn_shot(i,0,0)
		game._on_delayed_shot_requested({"gun":0,"angle":0.0,"delay":.3},i)
		game.spawn_well(Vector2(500,700),i)
	assert(game.use_pulse(2))
	assert(game.shots.size() == 3 and game.wells.size() == 3 and game.delayed_shots.size() == 3)
	for shot in game.shots: assert(shot.state.owner != 0)
	# Gravity ignores allies, affects every enemy of its owner, and shares damage guards.
	fresh(game)
	for i in range(1,4): game.players[i].state.pos = Vector2(500+i*5,750)
	var well = game.spawn_well(Vector2(500,750),0)
	game._step_wells(.01)
	for i in range(1,4): assert(game.players[i].state.hp < game.players[i].state.max_hp)
	assert(p.state.hp == p.state.max_hp)
	# Slot 3 claims a chest via a common command, stores it in the run inventory.
	fresh(game)
	var chest = game.supplies.put_item("weapon",1,target.state.pos)
	chest.age = 1.0
	game.apply_command(3,{"interact":true})
	assert(chest.opening_player == 3)
	game.supplies.step(1.51)
	assert("gun:1" in game.match_state.reserve_items(3))
	# Device/CPU/external command paths produce identical movement, aim and fire.
	fresh(game)
	var command := Command.idle(.4)
	command.dx = 1.0
	command.shoot = true
	var origin: Vector2 = p.state.pos
	game.command_source = func(i,_dt): return command.duplicate() if i == 0 else Command.idle()
	game.combat.step(.01)
	var expected: Vector2 = p.state.pos
	var clip: int = p.weapon().clip
	fresh(game)
	game.command_source = game.resolve_command
	for actor in game.players: actor.is_cpu = false
	assert(game.submit_command("hero-42",command) and not game.submit_command("unknown",command))
	game.combat.step(.01)
	assert(p.state.pos.is_equal_approx(expected) and p.state.pos != origin and p.weapon().clip == clip)
	assert(is_equal_approx(p.state.angle,.4))
	# A downed teammate cannot end the team battle; last surviving team wins once.
	fresh(game)
	game.players[1].state.hp = 0
	game._settle_round()
	assert(game.phase == "play")
	game.players[2].state.hp = 0
	game.players[3].state.hp = 0
	game._settle_round()
	assert(game.battle_outcome.participants == ["hero-42"] and game.scores == [1,0,0,0])
	game._settle_round()
	assert(game.scores == [1,0,0,0])
	# Field bounds and hazards use the second field including areas beyond the original size.
	fresh(game)
	target.state.pos = Vector2(1300,750)
	game.arena.apply_hazards(target,70.0)
	assert(target.state.hp == target.state.max_hp)
	target.state.pos = Vector2(1400,850)
	game.arena.apply_hazards(target,70.0)
	assert(target.state.hp < target.state.max_hp)
	game.arena.move_fighter(target.state,Vector2(900,900))
	assert(target.state.pos.x <= 1380 and target.state.pos.y <= 840)
	# Room/encounter resource carry keeps independent copies, resets only transient effects.
	p.state.hp = 3.0
	p.weapon().clip = 2
	p.weapon().reserve = 7
	p.weapon().mode = 1
	p.state.pulses = 1
	p.state.roll = .2
	p.state.empty_casing_charge = true
	var inventory: Array = p.inventory.duplicate(true)
	p.move_to_room(Vector2(180,200))
	assert(p.state.hp == 3 and p.inventory == inventory and p.state.roll == .2)
	p.begin_encounter(Vector2(180,250))
	assert(p.state.hp == 3 and p.inventory == inventory and p.state.pulses == 1)
	assert(p.state.roll == 0 and not p.state.empty_casing_charge)
	# Run inventory needs neither preparation UI nor match series/progression.
	var run_inventory = Inventory.new(12,4)
	assert(run_inventory.valid_slot(3) and run_inventory.gold == [12,12,12,12])
	assert(run_inventory.store_field_weapon(3,1))
	assert("gun:1" in run_inventory.reserve_items(3))
	assert(run_inventory.grant_item(3,18) and run_inventory.grant_item(3,18))
	assert(run_inventory.Items.relic_ids(run_inventory.builds[3].owned).count(18) == 2)
	assert(run_inventory.grant_item(3,3) and not run_inventory.grant_item(3,3))
	# Two teams with two actors each: a dead ally shares the team result, no duplicate score.
	fresh(game)
	game.roster.participants[1].team = "solo"
	p.state.hp = 0
	game.players[2].state.hp = 0
	game.players[3].state.hp = 0
	game._settle_round()
	assert(game.battle_outcome.participants == ["hero-42","bot-17"] and game.scores == [1,1,0,0])
	# Reordering catalog arrays preserves type IDs and instance token meaning.
	var catalog = game.Catalog
	var definition: Dictionary = game.Weapons.definition(1).duplicate(true)
	catalog.data.guns.reverse()
	assert(game.Weapons.definition(1) == definition)
	assert(game.Weapons.new_inventory_entry(1).clip == definition.mag)
	catalog.data.guns.reverse()
	assert(game.Weapons.definition(-1).is_empty())
	print("PASS: 1v3 CPU / second field, teams and targets, shared commands, authority without presentation, resource carry, run inventory, stable IDs")
	game.queue_free()
	await process_frame
	quit()
