extends Resource
# All artwork and its display scale belong to the theme, not collision geometry.
@export var floor_texture: Texture2D
@export var cover_texture: Texture2D
@export var wall_top: Texture2D
# Unframed materials for a shared wall surface; edges are derived from its union.
@export var connected_walls := false
@export var wall_edge: Texture2D
@export var wall_end: Texture2D
@export var wall_face: Texture2D
@export var corner: Texture2D
@export var door_jamb: Texture2D
@export var foundation: Texture2D
@export var tile_size := 48
@export var face_repeat := 96
@export var cap_height := 12.0
@export var pier_width := 32.0
@export var exterior_color := Color("090d10")
@export var floor_tint := Color(.72,.76,.76)
@export var floor_repeat := 0
@export var wall_rise := 0.0
@export var depth_sort := false
@export var shadow_length := 0.0
@export var floor_wash := Color(0,0,0,0)

func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if connected_walls and (wall_top == null or wall_face == null or wall_edge == null or wall_end == null):
		errors.append("Connected walls require unframed top, face, edge and end materials")
	if tile_size < 1 or face_repeat < 1: errors.append("Theme repeats must be positive")
	if floor_repeat < 0: errors.append("Floor repeat must be nonnegative")
	if not is_finite(wall_rise) or wall_rise < 0 or not is_finite(shadow_length) or shadow_length < 0: errors.append("Invalid depth dimensions")
	if not is_finite(cap_height) or cap_height <= 0 or not is_finite(pier_width) or pier_width <= 0:
		errors.append("Theme cap and pier dimensions must be positive")
	return errors
