extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var game=load("res://scenes/game/combat_lab.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	assert(game.launch_test("twin_halls",[],20))
	var p=game.players[0]
	# Give two large enemies clear attack areas without tightening ordinary spawns.
	var arrival: Vector2=game.room_catalog.twin_halls.field.spawns[0]
	p.move_to_room(arrival)
	var positions: Array=game.Encounter.spawn_positions(game.arena,arrival,4,[96.0,96.0,0.0,0.0])
	assert(positions.size()==4)
	for i in range(2): assert(game.Encounter.spawn_clearance(game.arena,positions[i],96))
	for i in range(positions.size()):
		assert(positions[i].distance_to(arrival)>=260 and not game.arena.solid(positions[i],20))
		for j in range(i): assert(positions[i].distance_to(positions[j])>=160)
	assert(positions==game.Encounter.spawn_positions(game.arena,arrival,4,[96.0,96.0,0.0,0.0]))
	# No clear attack area: keep a safe ordinary spawn for the existing fallback.
	var field=preload("res://scripts/world/field_definition.gd").new()
	field.field_id="narrow-elite-placement"
	field.field_rect=Rect2(0,0,1200,120)
	field.fighter_bounds=Rect2(20,20,1160,80)
	field.projectile_bounds=field.field_rect
	field.spawns=PackedVector2Array([Vector2(60,60)])
	assert(game.arena.configure_field(field,1).is_empty())
	positions=game.Encounter.spawn_positions(game.arena,Vector2(60,60),2,[96.0,0.0])
	assert(positions.size()==2 and not game.Encounter.spawn_clearance(game.arena,positions[0],96))
	game.queue_free()
	await process_frame
	print("PASS: large enemies prefer clear floor, maintain entry/separation/path constraints, deterministic narrow fallback")
	quit()
