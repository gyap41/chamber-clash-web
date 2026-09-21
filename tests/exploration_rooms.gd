extends SceneTree
const Rooms = preload("res://scripts/game/exploration_rooms.gd")
const Navigation = preload("res://scripts/ai/cpu_navigation.gd")
func _initialize() -> void:
	call_deferred("run")
func key(game, pressed: bool, echo: bool = false) -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_F
	event.pressed = pressed
	event.echo = echo
	game._input(event)
	if pressed: game._unhandled_key_input(event)
func snapshot(player, inventory) -> Dictionary:
	var state: Dictionary = player.state.duplicate(true)
	state.erase("pos")
	return {"state":state,"weapons":player.inventory.duplicate(true),
		"wounds":player.rally_wounds.duplicate(true),"relics":player.relics.duplicate(),
		"builds":inventory.builds.duplicate(true),"gold":inventory.gold.duplicate()}
func reachable(arena, start: Vector2, target: Vector2) -> bool:
	var frontier: Array[Vector2i] = [Vector2i.ZERO]
	var visited := {Vector2i.ZERO:true}
	var cursor := 0
	while cursor < frontier.size() and cursor < Navigation.MAX_NODES:
		var cell := frontier[cursor]
		cursor += 1
		var point := start+Vector2(cell)*Navigation.CELL
		if point.distance_to(target) <= Rooms.INTERACT_RADIUS and Navigation.segment_clear(arena,point,target): return true
		for offset in [Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT,Vector2i.UP]:
			var next: Vector2i = cell+offset
			if visited.has(next) or not Navigation.segment_clear(arena,point,start+Vector2(next)*Navigation.CELL): continue
			visited[next] = true
			frontier.append(next)
	return false
func capture(name: String) -> void:
	if "--capture" not in OS.get_cmdline_user_args(): return
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png("res://.local/two-rooms-"+name+".png")
	assert(error == OK)
func run() -> void:
	assert(Rooms.validation_errors().is_empty())
	root.size = Vector2i(1120,800)
	var game = load("res://scenes/game/exploration.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.set_pause_reason("focus",false)
	var player = game.players[0]
	var inventory = game.exploration.inventory
	var roster = game.roster
	assert(game.exploration.room_id == Rooms.START_ROOM and game.doors.size() == 1)
	assert(game.doors[0].get_index() < game.arena.get_node("Players").get_index())
	assert(not game.try_enter_door())
	check_boundary(game.arena,Vector2(1050,300),Vector2(110,300))
	assert(reachable(game.arena,player.state.pos,Rooms.door(Rooms.START_ROOM,"east").position))
	player.hurt(2.0)
	player.weapon().clip = 2
	player.weapon().reserve = 7
	player.weapon().mode = 1
	player.start_reload()
	player.state.reload *= .5
	player.state.shot = .4
	player.state.dodge = .8
	player.state.roll = .2
	player.state.inv = .15
	player.state.melee = .3
	player.state.shield = .7
	player.state.holster = .6
	player.state.echo_holster_cd = .9
	player.state.empty_casing_charge = true
	player.state.pulses = 1
	inventory.gold[0] = 13
	var before := snapshot(player,inventory)
	player.state.pos = Rooms.door(Rooms.START_ROOM,"east").position
	player.sync_visual()
	game.refresh_hud()
	await capture("workshop-door")
	game.set_pause_reason("menu",true)
	key(game,true)
	assert(game.exploration.room_id == Rooms.START_ROOM)
	key(game,false)
	game.set_pause_reason("menu",false)
	game.exploration.encounter_status = "active"
	assert(not game.try_enter_door())
	game.exploration.encounter_status = "none"
	player.state.hp = 0
	assert(not game.try_enter_door())
	player.state.hp = before.state.hp
	game.spawn_shot(0,0,0)
	game.spawn_well(Vector2(400,100),0)
	game._on_delayed_shot_requested({"gun":0,"angle":0.0,"delay":.3},0)
	game.mouse_fire_held = true
	player.buffered_fire = .1
	player.buffered_switch = .1
	game.submit_command("p1",{"shoot":true})
	key(game,true)
	assert(game.exploration.room_id == "workshop_annex")
	assert(player.state.pos == Vector2(220,300))
	check_boundary(game.arena,Vector2(70,300),Vector2(1010,300))
	assert(snapshot(player,inventory) == before)
	assert(game.players[0] == player and game.roster == roster and game.exploration.inventory == inventory)
	assert(game.shots.is_empty() and game.wells.is_empty() and game.delayed_shots.is_empty())
	assert(game.submitted_commands.is_empty() and not game.mouse_fire_held)
	assert(player.buffered_fire == 0 and player.buffered_switch == 0)
	assert(game.nearby_door().is_empty() and not game.try_enter_door())
	assert(game.arena.get_node("CombatCamera").zoom == Vector2.ONE)
	assert(reachable(game.arena,player.state.pos,Rooms.door("workshop_annex","west").position))
	# A held mouse and key-repeat must not act in the destination room.
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	game._unhandled_input(click)
	assert(not game.mouse_fire_held)
	click.pressed = false
	game._input(click)
	assert(not game.fire_requires_release)
	player.state.pos = Rooms.door("workshop_annex","west").position
	player.sync_visual()
	key(game,true,true)
	key(game,true)
	assert(game.exploration.room_id == "workshop_annex")
	game.refresh_hud()
	await capture("annex-door")
	key(game,false)
	# Many zero-time crossings cannot heal, reload, reset timers, reroll or duplicate doors.
	for crossing in range(20):
		player.state.pos = Rooms.room(game.exploration.room_id).doors[0].position
		key(game,true)
		key(game,false)
		assert(snapshot(player,inventory) == before)
		assert(game.doors.size() == 1 and game.players.size() == 1)
		assert(game.arena.get_node("Walls").get_child_count() == 10)
		assert(game.arena.get_node("Spawns").get_child_count() == 1)
	assert(game.exploration.visited_rooms.size() == 2)
	# Real simulation advances retained timers once; ordinary reload completes normally.
	game.command_source = func(_i,_dt): return game.Command.idle(0)
	game._physics_process(.1)
	assert(is_equal_approx(player.state.reload,before.state.reload-.1))
	assert(is_equal_approx(player.state.dodge,.7))
	assert(is_equal_approx(player.rally_wounds[0].time,before.wounds[0].time-.1))
	assert(player.weapon().clip == 2 and player.weapon().reserve == 7)
	game._physics_process(before.state.reload)
	assert(player.state.reload == 0 and player.weapon().clip == 9 and player.weapon().reserve == 0)
	assert(game.result.is_empty())
	game.start_exploration(21)
	assert(game.exploration.room_id == Rooms.START_ROOM and game.exploration.visited_rooms.size() == 1)
	assert(game.arena.definition.field_id == Rooms.START_ROOM and game.doors.size() == 1)
	assert(player.state.pos == Vector2(170,300) and player.state.hp == player.state.max_hp)
	game.queue_free()
	await process_frame
	print("PASS: two reachable rooms, reciprocal doors, 20 crossings preserve resources/timers, input release, cleanup, pause/death guards, reload and restart")
	quit()

func check_boundary(arena, opening: Vector2, closed: Vector2) -> void:
	var corridor_actor := {"pos":opening}
	arena.move_fighter(corridor_actor,Vector2(0,-200))
	assert(corridor_actor.pos.y >= 258)
	arena.move_fighter(corridor_actor,Vector2(0,400))
	assert(corridor_actor.pos.y <= 342)
	var invalid = arena.definition.duplicate(true)
	invalid.floor_regions.append(Rect2(-10,-10,5,5))
	assert(not invalid.validation_errors(1).is_empty())
	invalid = arena.definition.duplicate(true)
	invalid.wall_face_textures[999] = null
	assert(not invalid.validation_errors(1).is_empty())
	assert(not arena.solid(opening,14))
	assert(arena.solid(closed,2))
	assert(arena.solid(Vector2(700,100),2))
	assert(arena.solid(Vector2(700,530),2))
	var actor := {"pos":Vector2(700,300)}
	arena.move_fighter(actor,Vector2(0,-500))
	assert(actor.pos.y >= 142)
	arena.move_fighter(actor,Vector2(0,1000))
	assert(actor.pos.y <= 498)
	var wall = arena.get_node("Walls").get_child(3)
	var original: Rect2 = wall.collision_rect()
	var texture = wall.surface_texture
	wall.surface_texture = null
	assert(wall.collision_rect() == original and arena.solid(Vector2(700,100),2))
	wall.surface_texture = texture
