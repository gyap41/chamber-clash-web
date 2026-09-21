extends Resource
const Field = preload("res://scripts/world/field_definition.gd")
@export var display_name := ""
@export var field: Field
@export var doors: Array[Dictionary] = []
func snapshot() -> Dictionary:
	return {"name":display_name,"field":field,"doors":doors.duplicate(true)}

func validation_errors(radius: float = 14.0) -> PackedStringArray:
	var errors := PackedStringArray()
	if display_name.is_empty(): errors.append("Room display name is required")
	if field == null: return PackedStringArray(["Room field is required"])
	errors.append_array(field.validation_errors(1,radius))
	for entry in doors:
		for key in ["id","target_room","target_door"]:
			if not entry.get(key) is String or entry.get(key,"").is_empty(): errors.append("Door string is required: "+key)
		for key in ["position","arrival","direction"]:
			if not entry.get(key) is Vector2:
				errors.append("Door vector is required: "+key)
			elif not entry[key].is_finite(): errors.append("Door vector must be finite")
		if entry.get("direction") not in [Vector2.LEFT,Vector2.RIGHT]: errors.append("Door renderer currently supports left/right only")
	return errors
