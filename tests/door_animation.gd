extends SceneTree
const Door = preload("res://scripts/world/exploration_door.gd")
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	assert(Door.gate_style == "integrated" and Door.gate_textures.size() == 4)
	for texture in Door.gate_textures.values():
		assert(texture.resource_path.begins_with("res://assets/stages/ashen-foundry-v2/dungeon-gate/"))
	var door := Door.new()
	root.add_child(door)
	assert(door.passage_ready())
	door.set_locked(true)
	assert(not door.passage_ready())
	door.step(.175)
	assert(door.closure > 0 and door.closure < 1)
	door.set_locked(true)
	door.step(.175)
	assert(door.closure == 1 and door.impact > 0)
	door.set_locked(false)
	door.step(.3)
	assert(not door.passage_ready())
	# A new wave reverses the same gate without resetting its position.
	var previous: float = door.closure
	door.set_locked(true)
	assert(door.closure == previous)
	door.step(.35)
	assert(door.closure == 1)
	door.set_locked(false)
	door.step(.65)
	assert(door.passage_ready())
	door.free()
	var game = load("res://scenes/game/exploration.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.set_pause_reason("focus",false)
	var gate = game.doors[0]
	Door.gate_textures[gate.door_id] = Door.BARRIER
	gate.set_locked(true)
	gate.step(.35)
	gate.set_locked(false)
	gate.step(.2)
	var entry: Dictionary = game.room_data(game.exploration.room_id).doors[0]
	game.players[0].state.pos = entry.position
	game.door_armed = true
	assert(not game.try_enter_door(true))
	var paused_closure: float = gate.closure
	game.set_pause_reason("menu",true)
	game._physics_process(1.0)
	assert(gate.closure == paused_closure)
	game.set_pause_reason("menu",false)
	gate.step(.65)
	assert(game.try_enter_door(true))
	assert(game.exploration.room_id == entry.target_room)
	assert(game.doors.all(func(node): return node.closure == 0.0))
	Door.gate_textures.clear()
	game.queue_free()
	await process_frame
	# Width must never become the travel distance, including the edge-on gates.
	var structure = preload("res://scripts/world/portcullis_structure.gd")
	assert(is_equal_approx(structure.lift(0.0),70.0))
	assert(is_equal_approx(structure.lift(1.0),0.0))
	Door.gate_style = "recessed"
	for direction in [Vector2.UP,Vector2.DOWN,Vector2.LEFT,Vector2.RIGHT]:
		for width in [112.0,144.0,176.0]:
			Door.gate_textures["test"] = Door.BARRIER
			var built := Door.new()
			built.configure({"id":"test","position":Vector2(200,200),"direction":direction,"width":width},"test",null)
			root.add_child(built)
			var near_foot: float = width*.5 if direction.x != 0 else 0.0
			assert(built.position == Vector2(200,200)+structure.mount(direction)+Vector2(0,near_foot))
			assert(built.gate_origin == Vector2(0,-near_foot))
			assert(built.get_node("GateContactShadow").z_index < 0)
			built.set_locked(true)
			built.step(.35)
			assert(built.closure == 1.0)
			built.set_locked(false)
			built.step(.65)
			assert(built.passage_ready())
			built.free()
	Door.gate_style = "legacy"
	Door.gate_textures.clear()
	print("PASS: door close/open, repeated state, reversal and passage readiness")
	quit()
