extends Resource
# Local sprite bounds and collision bounds are deliberately independent.
@export var placement_id := ""
@export var position := Vector2.ZERO
@export var texture: Texture2D
@export var visual_rect := Rect2(-24,-48,48,48)
@export var collision := Rect2()
@export var projectile_collision := Rect2()
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
# Mirror the picture left-right (variation for repeated pieces; lit from above, so both sides read).
@export var flip_h := false
@export var water_surface := Rect2() # Normalized texture coordinates, inset from masonry.
@export var water_sunlight := false
@export_enum("None", "Lamp", "Campfire", "Furnace") var fire_kind := 0
# Soft copy of the picture dropped toward the lower right on the floor (light from the upper left).
@export var drop_shadow := false

# 2026-10-04: solid scenery blocks shots through its body, without stealing walkable floor.
# Empty override derives a vertical body using the authored footprint width. Decals/lights
# without a footprint stay nonblocking; unusual silhouettes can specify an exact rectangle.
func projectile_rect() -> Rect2:
	if projectile_collision.has_area(): return projectile_collision
	if not collision.has_area(): return Rect2()
	var body := Rect2(Vector2(collision.position.x,visual_rect.position.y),Vector2(collision.size.x,visual_rect.size.y))
	return collision.merge(body)

func validation_errors(field: Rect2) -> PackedStringArray:
	var errors := PackedStringArray()
	if placement_id.is_empty() or not position.is_finite() or not field.has_point(position): errors.append("Invalid placement ID or position")
	if not visual_rect.position.is_finite() or not visual_rect.size.is_finite() or visual_rect.size.x <= 0 or visual_rect.size.y <= 0:
		errors.append("Invalid placement visual rectangle")
	if collision != Rect2():
		if not collision.position.is_finite() or not collision.size.is_finite() or collision.size.x <= 0 or collision.size.y <= 0 or not field.encloses(Rect2(position+collision.position,collision.size)):
			errors.append("Invalid placement collision")
	if projectile_collision != Rect2():
		if not projectile_collision.position.is_finite() or not projectile_collision.size.is_finite() or not projectile_collision.has_area():
			errors.append("Invalid projectile collision")
		if floor_decal or surface_overlay: errors.append("Floor overlays cannot block projectiles")
	if layer not in [0,1] or not is_finite(light_radius) or light_radius < 0 or not is_finite(light_energy) or light_energy < 0:
		errors.append("Invalid placement layer or light")
	if not light_offset.is_finite(): errors.append("Invalid light offset")
	if water_surface != Rect2() and (not water_surface.position.is_finite() or not water_surface.size.is_finite() or not water_surface.has_area() or not Rect2(0,0,1,1).encloses(water_surface)):
		errors.append("Invalid normalized water surface")
	if water_sunlight and not water_surface.has_area(): errors.append("Water sunlight requires a water surface")
	if fire_kind < 0 or fire_kind > 3 or (fire_kind > 0 and (texture == null or light_radius <= 0)):
		errors.append("Fire ambience requires a textured light source")
	if floor_mark not in [0,1,2]: errors.append("Invalid floor mark")
	if floor_decal and (collision != Rect2() or light_radius > 0): errors.append("Floor decals cannot block movement or emit light")
	if surface_overlay and (floor_decal or collision != Rect2() or light_radius > 0): errors.append("Surface overlays must be shallow, nonblocking attachments")
	if shadow_rect != Rect2() and (not shadow_rect.position.is_finite() or not shadow_rect.size.is_finite() or shadow_rect.size.x <= 0 or shadow_rect.size.y <= 0): errors.append("Invalid contact shadow")
	if floor_motif not in [0,1] or (floor_motif != 0 and not floor_decal): errors.append("Floor motifs require floor decal layer")
	return errors
