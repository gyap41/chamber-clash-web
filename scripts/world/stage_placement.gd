extends Resource
# Local sprite bounds and collision bounds are deliberately independent.
@export var placement_id := ""
@export var position := Vector2.ZERO
@export var texture: Texture2D
@export var visual_rect := Rect2(-24,-48,48,48)
@export var collision := Rect2()
@export_enum("Background", "Foreground") var layer := 0
@export var light_radius := 0.0
@export var light_color := Color(1,.65,.3)
@export var light_energy := 1.0

func validation_errors(field: Rect2) -> PackedStringArray:
	var errors := PackedStringArray()
	if placement_id.is_empty() or not position.is_finite() or not field.has_point(position): errors.append("Invalid placement ID or position")
	if not visual_rect.position.is_finite() or not visual_rect.size.is_finite() or visual_rect.size.x <= 0 or visual_rect.size.y <= 0:
		errors.append("Invalid placement visual rectangle")
	if collision != Rect2():
		if not collision.position.is_finite() or not collision.size.is_finite() or collision.size.x <= 0 or collision.size.y <= 0 or not field.encloses(Rect2(position+collision.position,collision.size)):
			errors.append("Invalid placement collision")
	if layer not in [0,1] or not is_finite(light_radius) or light_radius < 0 or not is_finite(light_energy) or light_energy < 0:
		errors.append("Invalid placement layer or light")
	return errors
