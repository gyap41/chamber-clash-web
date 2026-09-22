extends RefCounted
static func paint(canvas: Node2D, view: Dictionary) -> void:
	preload("res://scripts/visuals/enemy_sheet_visual.gd").paint(canvas,view,true)
