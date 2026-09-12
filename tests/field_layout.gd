extends SceneTree
const Definition = preload("res://scripts/world/field_definition.gd")
const Duel = preload("res://data/fields/duel.tres")
const Validation = preload("res://data/fields/validation.tres")
const Resources = preload("res://scripts/game/encounter_resources.gd")
const Battle = preload("res://tests/helpers/battle.gd")

func _initialize() -> void: call_deferred("run")

func check_layout(arena, definition, expected_walls: Array, expected_spawns: Array) -> void:
	assert(arena.field_rect == definition.field_rect)
	assert(arena.fighter_bounds == definition.fighter_bounds)
	assert(arena.projectile_bounds == definition.projectile_bounds)
	var bounds: Rect2 = definition.field_rect
	assert(arena.get_node("Floor").polygon == PackedVector2Array([bounds.position,Vector2(bounds.end.x,bounds.position.y),bounds.end,Vector2(bounds.position.x,bounds.end.y)]))
	assert(arena.get_node("Floor").color == Color(0.188,0.208,0.196,1))
	assert(arena.get_node("Walls").get_child_count() == expected_walls.size())
	for i in range(expected_walls.size()):
		assert(arena.get_node("Walls/Wall%d" % (i+1)).collision_rect() == expected_walls[i])
		assert(arena.solid(expected_walls[i].get_center(),2))
	assert(arena.get_node("Spawns").get_child_count() == expected_spawns.size())
	for i in range(expected_spawns.size()): assert(arena.spawn_position(i) == expected_spawns[i])
	var expected_supplies := {
		"InitialWeapons":[Vector2(560,125),Vector2(560,475)],
		"Weapons":[Vector2(560,205),Vector2(560,395)],
		"Ammo":[Vector2(450,300),Vector2(670,300)],
		"Legendary":[Vector2(560,205),Vector2(560,395)],
		"Relics":[Vector2(460,220),Vector2(660,380)]}
	assert(arena.get_node("Supplies/Spawns").get_child_count() == expected_supplies.size())
	for group in expected_supplies:
		for i in range(2):
			assert(arena.get_node("Supplies/Spawns/%s/Point%d" % [group,i+1]).position == expected_supplies[group][i])

func run() -> void:
	# Literal baselines from the two former scene layouts, independent of the new resources.
	var duel_walls := [Rect2(240,160,80,85),Rect2(800,355,80,85),Rect2(515,250,90,90)]
	var validation_walls := [Rect2(350,160,120,220),Rect2(970,355,120,305),Rect2(680,440,80,90)]
	var duel_spawns := [Vector2(170,300),Vector2(950,300)]
	var validation_spawns := [Vector2(170,300),Vector2(1270,300),Vector2(1270,600),Vector2(1270,780)]
	var arena = load("res://scenes/world/arena.tscn").instantiate()
	var second = load("res://scenes/world/arena_validation.tscn").instantiate()
	root.add_child(arena)
	root.add_child(second)
	assert(Duel.field_rect == Rect2(0,0,1120,600) and Duel.fighter_bounds == Rect2(60,82,1000,458) and Duel.projectile_bounds == Rect2(32,37,1056,533))
	assert(Validation.field_rect == Rect2(0,0,1440,900) and Validation.fighter_bounds == Rect2(60,82,1320,758) and Validation.projectile_bounds == Rect2(32,37,1376,833))
	check_layout(arena,Duel,duel_walls,duel_spawns)
	check_layout(second,Validation,validation_walls,validation_spawns)
	# Share one definition between live fields; editing/removing runtime objects cannot alter it.
	assert(second.configure_field(Duel).is_empty())
	arena.get_node("Walls/Wall1").position = Vector2(90,90)
	arena.get_node("Walls/Wall2").free()
	arena.get_node("Spawns/P1").position = Vector2(100,100)
	arena.get_node("Supplies/Spawns/Ammo/Point1").position = Vector2(100,120)
	arena.runtime_definition.supply_points.Ammo[0] = Vector2(100,130)
	assert(Duel.walls[0] == duel_walls[0] and Duel.spawns[0] == duel_spawns[0])
	assert(Duel.supply_points.Ammo[0] == Vector2(450,300))
	check_layout(second,Duel,duel_walls,duel_spawns)
	for repeat in range(3):
		assert(arena.configure_field(Duel).is_empty())
		check_layout(arena,Duel,duel_walls,duel_spawns)
	# An in-memory producer uses exactly the same builder. No random algorithm or scene file.
	var produced := Definition.new()
	produced.field_id = "in-memory"
	produced.field_rect = Rect2(100,50,800,500)
	produced.fighter_bounds = Rect2(120,70,760,460)
	produced.projectile_bounds = Rect2(110,60,780,480)
	produced.walls = [Rect2(400,220,60,70)]
	produced.spawns = PackedVector2Array([Vector2(180,150),Vector2(820,450)])
	assert(arena.configure_field(produced,2).is_empty())
	assert(arena.line_blocked(Vector2(380,250),Vector2(480,250)))
	assert(arena.spawn_position(1) == Vector2(820,450))
	produced.walls[0] = Rect2(600,200,20,20)
	assert(arena.solid(Vector2(430,250),2)) # private snapshot/live layout stays unchanged
	arena.queue_free()
	second.queue_free()

	var game = load("res://scenes/game/main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	Battle.passive_opponents(game)
	Battle.start(game,1)
	var p = game.players[0]
	p.state.hp = 3.25
	p.weapon().clip = 2
	p.weapon().reserve = 7
	p.weapon().mode = 1
	p.state.pulses = 1
	p.state.dodge = .75
	p.state.roll = .2
	p.state.empty_casing_charge = true
	p.state.ai_combat_path = [Vector2(400,400)]
	p.state.ai_enemy_pos = Vector2(950,300)
	assert(p.add_relic(18))
	p.temporary_relic = 18
	p.temporary_relic_slot = p.relics.size()-1
	var resources: Dictionary = Resources.capture(p)
	var money: Array = game.match_state.gold.duplicate()
	var builds: Array = game.match_state.builds.duplicate(true)
	var scores: Array = game.scores.duplicate()
	var remaining: float = game.remaining
	var match_instance = game.match_state
	var roster = game.roster
	game.spawn_shot(0,0,0)
	game.spawn_well(Vector2(400,100),0)
	game._on_delayed_shot_requested({"gun":0,"angle":0.0,"delay":.3},0)
	game.supplies.put_item("ammo",0,Vector2(400,100))
	game.mouse_fire_held = true
	game.submit_command("p1",{"shoot":true})
	# Failed validation is atomic, including transient objects and inputs.
	var wall_before = game.arena.get_node("Walls/Wall1")
	var invalid: Definition = Duel.duplicate(true)
	invalid.spawns[0] = Vector2(260,180)
	assert(not game.switch_field(invalid).is_empty())
	assert(game.arena.get_node("Walls/Wall1") == wall_before and game.shots.size() == 1)
	assert(game.mouse_fire_held and not game.submitted_commands.is_empty())
	assert(Resources.capture(p) == resources)
	for malformed in [null,Definition.new()]: assert(not game.switch_field(malformed).is_empty())
	invalid = Duel.duplicate(true)
	invalid.field_rect.size.x = NAN
	assert(not game.switch_field(invalid).is_empty())
	invalid = Duel.duplicate(true)
	invalid.spawns.resize(1)
	assert(not game.switch_field(invalid).is_empty())
	invalid = Duel.duplicate(true)
	invalid.projectile_bounds.size.x = 2000
	assert(not game.switch_field(invalid).is_empty())
	invalid = Duel.duplicate(true)
	invalid.walls[0] = Rect2(0,0,-20,20)
	assert(not game.switch_field(invalid).is_empty())
	invalid = Duel.duplicate(true)
	invalid.supply_points.Ammo = "invalid"
	assert(not game.switch_field(invalid).is_empty())

	# Room transition: keep participants/resources/timers, remove only old-field objects and paths.
	assert(game.switch_field(Validation).is_empty())
	assert(game.players[0] == p and game.match_state == match_instance and game.roster == roster)
	assert(Resources.capture(p) == resources and p.state.dodge == .75 and p.state.roll == .2)
	assert(p.state.empty_casing_charge and not p.state.has("ai_combat_path") and not p.state.has("ai_enemy_pos"))
	assert(game.shots.is_empty() and game.wells.is_empty() and game.delayed_shots.is_empty() and game.supplies.items.is_empty())
	assert(not game.mouse_fire_held and game.submitted_commands.is_empty())
	assert(game.match_state.gold == money and game.match_state.builds == builds and game.scores == scores)
	assert(game.phase == "play" and game.remaining == remaining)
	assert(game.players[1].state.pos == validation_spawns[1] and game.players.size() == 2)
	assert(game.arena.get_node("CombatCamera").zoom.is_equal_approx(Vector2.ONE*(2.0/3.0)))
	# New encounter: reset transient actor effects without healing, rearming or reapplying builds.
	assert(game.switch_field(Duel,true).is_empty())
	assert(Resources.capture(p) == resources and p.state.roll == 0 and p.state.dodge == 0)
	assert(not p.state.empty_casing_charge and game.fighters[0] == p.state)
	assert(game.arena.get_node("CombatCamera").zoom == Vector2.ONE)
	assert(game.arena.get_node("CombatCamera").position == Vector2(0,-90))
	assert(game.match_state.gold == money and game.match_state.builds == builds and game.scores == scores)
	check_layout(game.arena,Duel,duel_walls,duel_spawns)
	# Missing supply groups are valid (e.g. an empty room); ordinary spawn scheduling is harmless.
	produced.walls = [Rect2(400,220,60,70)]
	assert(game.switch_field(produced).is_empty())
	game.supplies.spawn_group("Ammo","ammo")
	assert(game.supplies.items.is_empty())
	game.players[1].state.pos = Vector2(820,450)
	game.command_source = func(i,_dt): return game.Command.idle(game.players[i].state.angle)
	game.combat.step(.01)
	assert(game.phase == "play" and is_equal_approx(p.state.hp,3.25))
	# Same collision and projectile code operates on the newly produced geometry.
	game.spawn_shot(0,0,0,{"pos":Vector2(350,250),"speed":420.0})
	var shot = game.shots.back()
	shot.step(.3,game.arena,game.players[1])
	assert(shot.state.life <= 0 and shot.state.pos.x < 400)
	game.queue_free()
	await process_frame
	print("PASS: both field layouts reproduced, reusable isolated definitions, in-memory producer, atomic rejection, room/encounter resource carry, common combat")
	quit()
