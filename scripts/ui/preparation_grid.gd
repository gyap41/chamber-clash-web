extends RefCounted
# Preparation-only presentation. Purchase, selection and edit policy stay in the controller.
const RelicGridCell = preload("res://scripts/ui/relic_grid_cell.gd")
const RelicChip = preload("res://scripts/ui/relic_chip.gd")
const Relics = preload("res://scripts/catalog/relic_catalog.gd")
const Weapons = preload("res://scripts/catalog/weapon_catalog.gd")
const CELL_SIZE := 50
const CELL_GAP := 4
static func build(view, parent: Node, state, i: int, build: Dictionary) -> void:
	var size: Vector2i = state.MAX_GRID_SIZE
	var occupied: Dictionary = state.occupied_cells(i)
	var positions: Dictionary = build.get("positions",{})
	var grid := GridContainer.new()
	grid.name = "Grid"
	grid.columns = size.x
	grid.position = Vector2(20,77)
	grid.add_theme_constant_override("h_separation",CELL_GAP)
	grid.add_theme_constant_override("v_separation",CELL_GAP)
	parent.add_child(grid)
	for y in range(size.y):
		for x in range(size.x):
			var cell := Vector2i(x,y)
			var panel := RelicGridCell.new()
			panel.inventory_state = state
			panel.player_index = i
			panel.cell = cell
			panel.on_drop = view.place_relic
			panel.on_click = view.click_cell
			panel.custom_minimum_size = Vector2(CELL_SIZE,CELL_SIZE)
			var style := StyleBoxFlat.new()
			style.bg_color = Color("243747")
			style.border_color = Color("456174")
			style.set_border_width_all(1)
			if not state.usable_cells(i).has(cell):
				style.bg_color = Color("151f29")
				style.border_color = Color("2c3945")
				panel.tooltip_text = "未開放：バッグ拡張で使用可能になる領域"
				view.text_at(panel,"Locked","×",Rect2(18,14,24,24),18,Color("65727d"))
			if occupied.has(cell):
				var entry = occupied[cell]
				style.bg_color = Color("30758a") if state.is_gun(entry) else Color(Relics.definition(state.relic_id(entry)).color).darkened(.5)
				style.border_color = style.bg_color.lightened(.3)
				var chip := RelicChip.new()
				chip.entry = entry
				chip.grab_offset = cell-positions.get(entry,cell)
				chip.on_drag_start = view.select_entry
				chip.clip_text = true
				chip.tooltip_text = view.entry_info(entry).name+"\n"+view.entry_info(entry).desc
				chip.custom_minimum_size = Vector2(CELL_SIZE-4,CELL_SIZE-4)
				chip.position = Vector2(2,2)
				chip.add_theme_font_size_override("font_size",12)
				for name in ["normal","hover","pressed"]: chip.add_theme_stylebox_override(name,StyleBoxEmpty.new())
				chip.pressed.connect(view.click_cell.bind(cell))
				chip.focus_entered.connect(view.focus_entry.bind(entry))

				panel.add_child(chip)
				if positions.get(entry,cell) == cell:
					chip.text = "\n\n"+view.entry_info(entry).name.left(4)
					if state.is_gun(entry):
						var art := TextureRect.new()
						art.texture = Weapons.art(state.gun_id(entry))
						art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
						art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
						art.position = Vector2(7,3)
						art.size = Vector2(40,25)
						art.material = Weapons.Visuals.body_material(state.gun_id(entry),art.size)
						art.mouse_filter = Control.MOUSE_FILTER_IGNORE
						chip.add_child(art)
					else: view.add_item_art(chip,entry,Rect2(17,4,22,22),false)
				preload("res://scripts/ui/item_grid_appearance.gd").join_cells(panel,style,occupied,cell,entry,CELL_SIZE,CELL_GAP)
			panel.add_theme_stylebox_override("panel",style)
			grid.add_child(panel)
