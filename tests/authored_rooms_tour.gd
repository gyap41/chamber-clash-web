extends SceneTree
# Exercise actual collision-driven walking, transitions and preview selection across every authored room.
const A = preload("res://scripts/world/authored_rooms.gd")
const Reach = preload("res://scripts/world/room_reachability.gd")
var game
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	game = load("res://scenes/game/authored_rooms_preview.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	if game.room_picker.item_count != 20: fail("Room picker must expose all twenty rooms"); return
	for side in ["east","west"]:
		for index in range(A.ORDER.size()):
			var id: String = game.exploration.room_id
			var entry: Dictionary = game.door_data(id,side)
			var path := route(game.arena.runtime_definition,game.players[0].state.pos,entry.position)
			if path.is_empty(): fail("No walking route: "+id+" "+side); return
			if not walk(path): fail("Arena collision blocked route: "+id+" "+side); return
			game.door_armed = true
			if not game.try_enter_door(): fail("Door transition failed: "+id+" "+side); return
			if game.exploration.room_id != entry.target_room: fail("Wrong destination"); return
			await process_frame
		if game.exploration.room_id != A.ORDER[0]: fail("Tour did not close its ring"); return
	for index in range(A.ORDER.size()):
		game.select_preview_room(index)
		if game.exploration.room_id != A.ORDER[index]: fail("Room selection failed"); return
		if game.room_picker.selected != index: fail("Picker and current room disagree"); return
		await process_frame
	print("PASS: all twenty rooms walked east and west with Arena collision; 40 real door transitions; 20 room selections")
	game.queue_free()
	await process_frame
	quit(0)

func route(field, start: Vector2, target: Vector2) -> Array[Vector2]:
	var queue: Array[Vector2i] = [Vector2i.ZERO]
	var parents := {Vector2i.ZERO:Vector2i.ZERO}
	var cursor := 0
	while cursor < queue.size() and cursor < 16000:
		var cell := queue[cursor]
		cursor += 1
		var point := start+Vector2(cell)*32
		if point.distance_to(target) <= 48 and Reach.clear_segment(field,point,target):
			var result: Array[Vector2] = [target,point]
			while cell != Vector2i.ZERO:
				cell = parents[cell]
				result.append(start+Vector2(cell)*32)
			result.reverse()
			return result
		for step in [Vector2i.RIGHT,Vector2i.LEFT,Vector2i.UP,Vector2i.DOWN]:
			var next: Vector2i = cell+step
			if parents.has(next): continue
			if Reach.clear_segment(field,point,start+Vector2(next)*32):
				parents[next] = cell
				queue.append(next)
	return []

func walk(path: Array[Vector2]) -> bool:
	var player = game.players[0]
	for target in path:
		while player.state.pos.distance_to(target) > .1:
			var before: Vector2 = player.state.pos
			var delta: Vector2 = before.direction_to(target)*minf(4,before.distance_to(target))
			game.arena.move_fighter(player.state,delta,player.radius)
			if player.state.pos.distance_to(before+delta) > .1: return false
	return true

func fail(message: String) -> void:
	push_error(message)
	quit(1)
