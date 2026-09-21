extends Resource
# All artwork and its display scale belong to the theme, not collision geometry.
@export var floor_texture: Texture2D
@export var cover_texture: Texture2D
@export var wall_top: Texture2D
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

func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if tile_size < 1 or face_repeat < 1: errors.append("Theme repeats must be positive")
	if not is_finite(cap_height) or cap_height <= 0 or not is_finite(pier_width) or pier_width <= 0:
		errors.append("Theme cap and pier dimensions must be positive")
	return errors
