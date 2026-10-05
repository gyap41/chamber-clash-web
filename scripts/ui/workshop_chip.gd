extends "res://scripts/ui/relic_chip.gd"
var can_interact: Callable
var art_texture: Texture2D
var shape: Array = [Vector2i.ZERO]
const Preview = preload("res://scripts/ui/workshop_drag.gd")
func _get_drag_data(_pos: Vector2) -> Variant:
	if can_interact.is_valid() and not can_interact.call(): return null
	if on_drag_start.is_valid(): on_drag_start.call(entry)
	var preview := Preview.new()
	preview.shape = shape
	preview.texture = art_texture
	preview.offset = -Vector2(grab_offset)*60-Vector2(30,30)
	set_drag_preview(preview)
	return {"entry":entry,"grab_offset":grab_offset}
