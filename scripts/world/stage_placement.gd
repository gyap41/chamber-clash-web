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
@export var light_offset := Vector2.ZERO
@export var contact_shadow := false
# Authored local contact footprint; empty keeps legacy shadows.
@export var shadow_rect := Rect2()
@export var wall_shadow := false
# A short rear elbow connects a furnace outlet to the wall behind it.
@export var wall_flue := false
@export_enum("None", "Soot", "Scuff") var floor_mark := 0
@export var floor_decal := false
@export_enum("None", "CastingBed") var floor_motif := 0
# Shallow wall/floor attachments: above masonry, below every actor.
@export var surface_overlay := false
@export var tint := Color.WHITE

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
	if not light_offset.is_finite(): errors.append("Invalid light offset")
	if floor_mark not in [0,1,2]: errors.append("Invalid floor mark")
	if floor_decal and (collision != Rect2() or light_radius > 0): errors.append("Floor decals cannot block movement or emit light")
	if surface_overlay and (floor_decal or collision != Rect2() or light_radius > 0): errors.append("Surface overlays must be shallow, nonblocking attachments")
	if shadow_rect != Rect2() and (not shadow_rect.position.is_finite() or not shadow_rect.size.is_finite() or shadow_rect.size.x <= 0 or shadow_rect.size.y <= 0): errors.append("Invalid contact shadow")
	if floor_motif not in [0,1] or (floor_motif != 0 and not floor_decal): errors.append("Floor motifs require floor decal layer")
	return errors
