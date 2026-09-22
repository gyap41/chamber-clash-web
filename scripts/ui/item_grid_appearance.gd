extends RefCounted
const Items = preload("res://scripts/game/item_identity.gd")

# Both inventory screens share footprint joins, while keeping their own palette/layout.
static func join_cells(panel: Control, style: StyleBoxFlat, occupied: Dictionary, cell: Vector2i, entry, cell_size: float, gap: float, retain_cell_lines: bool = false) -> void:
	if not retain_cell_lines:
		var sides := {Vector2i.LEFT:"left",Vector2i.RIGHT:"right",Vector2i.UP:"top",Vector2i.DOWN:"bottom"}
		for edge in sides:
			if occupied.has(cell+edge) and Items.same_entry(occupied[cell+edge],entry):
				style.set("border_width_"+sides[edge],0)
	var inset := 1.0 if retain_cell_lines else 0.0
	for direction in [Vector2i.RIGHT,Vector2i.DOWN]:
		if occupied.has(cell+direction) and Items.same_entry(occupied[cell+direction],entry):
			var bridge := ColorRect.new()
			bridge.color = style.bg_color
			bridge.position = Vector2(cell_size,inset) if direction == Vector2i.RIGHT else Vector2(inset,cell_size)
			bridge.size = Vector2(gap,cell_size-inset*2) if direction == Vector2i.RIGHT else Vector2(cell_size-inset*2,gap)
			bridge.mouse_filter = Control.MOUSE_FILTER_IGNORE
			panel.add_child(bridge)
