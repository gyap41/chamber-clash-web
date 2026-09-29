extends SceneTree
const Authored = preload("res://scripts/world/authored_rooms.gd")
const Reach = preload("res://scripts/world/room_reachability.gd")
const Rooms = preload("res://scripts/game/exploration_rooms.gd")
func _initialize() -> void:
	var variants := 0
	for id in Authored.ORDER:
		for sides in Authored.connection_sets(id):
			variants += 1
			var room = Authored.make_room(id,sides)
			assert(room.validation_errors().is_empty(),id+str(sides))
			assert(Reach.reachable(room),id+str(sides))
			assert(room.doors.size() == sides.size())
	# Reorder the actual templates with fixed seeds: adjacency must not depend on preview numbering.
	for seed_value in range(10):
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		var order: Array = Authored.ORDER.duplicate()
		for i in range(order.size()-1,0,-1):
			var j := rng.randi_range(0,i)
			var swap = order[i]
			order[i] = order[j]
			order[j] = swap
		var catalog := {}
		for i in range(order.size()):
			var sides: Array = ["east"] if i == 0 else (["west"] if i == order.size()-1 else ["west","east"])
			var room = Authored.make_room(order[i],sides)
			for door in room.doors:
				door.target_room = order[i+(-1 if door.id == "west" else 1)]
			catalog[order[i]] = room
		assert(Rooms.validation_errors(14,catalog).is_empty(),str(seed_value))
	print("PASS: %d opening variants reachable; 10 shuffled chains validate, including terminal rooms" % variants)
	quit()
