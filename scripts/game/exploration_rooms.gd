extends RefCounted
# Authored room IDs and reciprocal door IDs, separate from the shared field geometry.
const START_ROOM := "workshop_trial"
const INTERACT_RADIUS := 64.0
const ROOMS := {
 "workshop_trial":preload("res://data/rooms/workshop_trial.tres"),
 "workshop_annex":preload("res://data/rooms/workshop_annex.tres")
}
static func room(id: String) -> Dictionary:
	return ROOMS[id].snapshot() if ROOMS.has(id) else {}
static func door(room_id: String, door_id: String) -> Dictionary:
	for entry in room(room_id).get("doors",[]):
		if entry.id == door_id: return entry
	return {}
static func validation_errors(radius: float = 14.0) -> PackedStringArray:
	var errors := PackedStringArray()
	for template in ROOMS.values(): errors.append_array(template.validation_errors(radius))
	if not errors.is_empty(): return errors
	for id in ROOMS:
		var definition = ROOMS[id].field
		errors.append_array(definition.validation_errors(1,radius))
		var ids := {}
		for entry in ROOMS[id].doors:
			if ids.has(entry.id): errors.append("Duplicate door ID in "+id)
			ids[entry.id] = true
			var partner := door(entry.target_room,entry.target_door)
			if partner.is_empty() or partner.target_room != id or partner.target_door != entry.id:
				errors.append("Door connection must be reciprocal: "+id)
			for point in [entry.position,entry.arrival]:
				if not definition.fighter_bounds.has_point(point) or not definition.floor_contains(point): errors.append("Door or arrival outside room: "+id)
				for wall in definition.walls:
					if point.distance_to(point.clamp(wall.position,wall.end)) < radius:
						errors.append("Door or arrival obstructed: "+id)
				for placement in definition.placements:
					if placement.collision == Rect2(): continue
					var rect := Rect2(placement.position+placement.collision.position,placement.collision.size)
					if point.distance_to(point.clamp(rect.position,rect.end)) < radius: errors.append("Door or arrival obstructed by placement: "+id)
			if entry.position.distance_to(entry.arrival) <= INTERACT_RADIUS:
				errors.append("Arrival must be outside the door activation range: "+id)
	return errors
