extends CanvasLayer
const Grid = preload("res://scripts/game/build_grid.gd")
const Widgets = preload("res://scripts/ui/hud_widgets.gd")
const Cell = preload("res://scripts/ui/relic_grid_cell.gd")
const Chip = preload("res://scripts/ui/workshop_chip.gd")
const Drag = preload("res://scripts/ui/workshop_drag.gd")
const Tray = preload("res://scripts/ui/relic_tray.gd")
const WorkshopSkin = preload("res://scripts/ui/workshop_skin.gd")
const Weapons = preload("res://scripts/catalog/weapon_catalog.gd")
const Relics = preload("res://scripts/catalog/relic_catalog.gd")
const Art = preload("res://scripts/ui/hud_assets.gd")
signal close_requested
signal closed
signal sound_requested(kind: String, owner: int)
var on_change: Callable
var draft
var selected = null
var placement_armed: bool = false
var body: Control
var panel: Control
var detail: Label
var detail_art: TextureRect
var detail_name: Label
var shade: ColorRect
var shield: Control
var back
var front
var hover_preview
var time: float = 0.0
var clock: float = 0.0
var closing: bool = false
var finished: bool = false
var message: String = ""
var error_time: float = 0.0
func _ready() -> void:
	layer = 30
	body = Control.new()
	body.name = "Root"
	body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	body.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(body)
	shade = ColorRect.new()
	shade.color = Color(0,0,0,.82)
	shade.size = Vector2(1120,800)
	body.add_child(shade)
	back = WorkshopSkin.new()
	body.add_child(back)
	panel = Control.new()
	panel.name = "Bag"
	panel.size = Vector2(1120,800)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(panel)
	front = WorkshopSkin.new()
	front.foreground = true
	body.add_child(front)
	shield = Control.new()
	shield.size = Vector2(1120,800)
	shield.mouse_filter = Control.MOUSE_FILTER_STOP
	body.add_child(shield)
	Widgets.button(body,"Close",Rect2(1058,76,36,36),"×",func(): close_requested.emit())
	if not draft.builds[0].equipped.is_empty(): selected = draft.builds[0].equipped[0]
	refresh()
	_sound("workshop_open")
	advance_animation(0)
func can_interact() -> bool:
	return time >= .5 and not closing and not finished
func _sound(kind: String) -> void:
	sound_requested.emit(kind,get_instance_id())
func _exit_tree() -> void:
	_sound("workshop_stop")
func begin_close() -> void:
	if closing or finished: return
	closing = true
	_sound("workshop_stop")
	_sound("workshop_close")
	shield.visible = true
	# Do not let a held drag survive the inventory's lifetime.
	get_viewport().gui_cancel_drag()
func advance_animation(delta: float) -> void:
	if finished: return
	clock += delta
	time = maxf(0,time-delta*.7/.25) if closing else minf(.7,time+delta)
	var zoom: float = .78+.22*back.smooth_progress((time-.08)/.37)
	for node in [back,panel,front]:
		node.pivot_offset = Vector2(560,420)
		node.scale = Vector2.ONE*zoom
	panel.modulate.a = back.smooth_progress((time-.43)/.12)
	for node in [back,front]:
		node.time = time
		node.clock = clock
		node.closing = closing
		node.queue_redraw()
	shield.visible = not can_interact()
	if closing and time<=0:
		finished = true
		closed.emit()
func _process(delta: float) -> void:
	advance_animation(delta)
	if finished: return
	if error_time>0:
		error_time -= delta
		if error_time<=0 and panel.has_node("Error"): panel.get_node("Error").hide()
	update_hover()
func info(entry) -> Dictionary:
	return Weapons.definition(draft.gun_id(entry)) if draft.is_gun(entry) else Relics.definition(draft.relic_id(entry))
func texture(entry) -> Texture2D:
	return Weapons.pickup_art(draft.gun_id(entry)) if draft.is_gun(entry) else Art.texture("relic_%02d" % draft.relic_id(entry))
func select(entry) -> void:
	if entry not in draft.builds[0].owned: return
	selected = entry
	var data: Dictionary = info(entry)
	detail_name.text = str(data.name)
	detail_art.texture = texture(entry)
	var description: String = preload("res://scripts/ui/item_description.gd").describe("weapon" if draft.is_gun(entry) else "relic",draft.gun_id(entry) if draft.is_gun(entry) else draft.relic_id(entry),draft,false,true)
	# The name and footprint already have visual representations.
	detail.text = description.substr(description.find("\n")+1).split("\n必要な面積：")[0].strip_edges()
func user_select(entry) -> void:
	if not can_interact(): return
	select(entry)
	placement_armed = true
	_sound("ui_select")
func start_drag(entry) -> void:
	user_select(entry)
	placement_armed = false
func fail(text: String) -> void:
	message = text
	error_time = 3
	_sound("ui_blocked")
func commit_layout() -> bool:
	if on_change.is_valid() and on_change.call(): return true
	fail("変更できません。配置と所持品を確認してください。")
	return false
func place(entry,cell: Vector2i) -> bool:
	if closing or finished: return false
	var success := false
	if not draft.place(0,entry,cell): fail("ここには配置できません。")
	else:
		success = commit_layout()
		if success:
			selected = entry
			placement_armed = false
			message = ""
			_sound("ui_place")
	refresh()
	return success
func remove(entry) -> bool:
	if closing or finished or entry not in draft.builds[0].equipped: return false
	var success := false
	if not draft.toggle(0,entry): fail("収納が満杯です。")
	else:
		success = commit_layout()
		if success:
			selected = entry
			placement_armed = false
			message = ""
			_sound("ui_remove")
	refresh()
	return success
func user_place(entry,cell: Vector2i) -> bool:
	return place(entry,cell) if can_interact() else false
func user_remove(entry) -> bool:
	return remove(entry) if can_interact() else false
func click_cell(cell: Vector2i) -> void:
	if not can_interact(): return
	var occupied: Dictionary = draft.occupied_cells(0)
	if occupied.has(cell): user_select(occupied[cell])
	elif selected != null and placement_armed: user_place(selected,cell)
func add_art(parent: Control,entry,bounds: Rect2) -> void:
	var image := TextureRect.new()
	image.texture = texture(entry)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.position = bounds.position
	image.size = bounds.size
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(image)
func refresh() -> void:
	for child in panel.get_children(): panel.remove_child(child); child.queue_free()
	build_grid()
	build_reserve()
	build_details()
	var error := Widgets.label(panel,"Error",Rect2(606,650,328,36),15)
	error.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	error.modulate = Color("f4bd94")
	error.text = message
	error.visible = not message.is_empty() and error_time>0
	if selected != null and selected in draft.builds[0].owned: select(selected)
func build_grid() -> void:
	var grid := Control.new()
	grid.name = "Grid"
	grid.position = Vector2(180,229)
	grid.size = Vector2(360,360)
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(grid)
	var occupied: Dictionary = draft.occupied_cells(0)
	var usable: Dictionary = draft.usable_cells(0)
	for y in range(6):
		for x in range(6):
			var pos := Vector2i(x,y)
			var cell := Cell.new()
			cell.name = "Cell_%d_%d" % [x,y]
			cell.position = Vector2(pos)*60
			cell.size = Vector2(58,58)
			cell.inventory_state = draft
			cell.cell = pos
			cell.on_drop = user_place
			cell.on_click = click_cell
			var style := StyleBoxFlat.new()
			style.bg_color = Color("17393a") if usable.has(pos) else Color("091b1d")
			style.border_color = Color("8d8058") if usable.has(pos) else Color("193331")
			style.set_border_width_all(1)
			if occupied.has(pos): style.bg_color = Color("1c4845")
			cell.add_theme_stylebox_override("panel",style)
			grid.add_child(cell)
			if occupied.has(pos):
				var entry = occupied[pos]
				var chip = make_chip(entry)
				chip.grab_offset = pos-draft.builds[0].positions[entry]
				chip.size = Vector2(58,58)
				for state in ["normal","hover","pressed","focus"]: chip.add_theme_stylebox_override(state,StyleBoxEmpty.new())
				chip.pressed.connect(click_cell.bind(pos))
				cell.add_child(chip)
				preload("res://scripts/ui/item_grid_appearance.gd").join_cells(cell,style,occupied,pos,entry,58,2)
	for entry in draft.builds[0].equipped:
		var rect: Rect2 = Drag.art_rect(draft.shape_of(entry),60)
		rect.position += Vector2(draft.builds[0].positions[entry])*60
		add_art(grid,entry,rect)
	var mask := Control.new()
	mask.name = "Hover"
	mask.size = Vector2(360,360)
	mask.clip_contents = true
	mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grid.add_child(mask)
	hover_preview = Drag.new()
	hover_preview.visible = false
	mask.add_child(hover_preview)
func make_chip(entry):
	var chip := Chip.new()
	chip.entry = entry
	chip.art_texture = texture(entry)
	chip.shape = draft.shape_of(entry)
	chip.can_interact = can_interact
	chip.on_drag_start = start_drag
	return chip
func build_reserve() -> void:
	var tray := Tray.new()
	tray.name = "Reserve"
	tray.position = Vector2(180,616)
	tray.size = Vector2(384,38)
	tray.on_drop = user_remove
	tray.add_theme_stylebox_override("panel",StyleBoxEmpty.new())
	panel.add_child(tray)
	var reserve: Array = draft.reserve_items(0)
	for i in range(Grid.RESERVE_CAPACITY):
		var slot := Panel.new()
		slot.position = Vector2(i*48,0)
		slot.size = Vector2(46,38)
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var style := StyleBoxFlat.new()
		style.bg_color = Color("173633")
		style.border_color = Color("5f7565")
		style.set_border_width_all(1)
		slot.add_theme_stylebox_override("panel",style)
		tray.add_child(slot)
		if i>=reserve.size(): continue
		var entry = reserve[i]
		var chip = make_chip(entry)
		chip.name = "Item_%d" % i
		chip.position = slot.position
		chip.size = slot.size
		for state in ["normal","hover","pressed","focus"]: chip.add_theme_stylebox_override(state,StyleBoxEmpty.new())
		chip.on_reserve_drop = user_remove
		chip.pressed.connect(user_select.bind(entry))
		tray.add_child(chip)
		add_art(chip,entry,Rect2(3,3,40,32))
	tray.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed and selected!=null and placement_armed: user_remove(selected))
func build_details() -> void:
	var box := Widgets.box(panel,"Details",Rect2(606,218,328,418))
	var style := StyleBoxFlat.new()
	style.bg_color = Color("0a2325")
	style.border_color = Color("7c734f")
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	box.add_theme_stylebox_override("panel",style)
	detail_name = Widgets.label(box,"Name",Rect2(20,16,288,42),23)
	detail_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	detail_art = TextureRect.new()
	detail_art.position = Vector2(95,64)
	detail_art.size = Vector2(138,120)
	detail_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	detail_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	detail_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(detail_art)
	var scroll := ScrollContainer.new()
	scroll.name = "DetailScroll"
	scroll.position = Vector2(20,195)
	scroll.size = Vector2(288,207)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	detail = Label.new()
	detail.name = "Detail"
	detail.custom_minimum_size.x = 266
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail.add_theme_font_size_override("font_size",16)
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	scroll.add_child(detail)
func update_hover(grid_position: Vector2 = Vector2.INF) -> void:
	if not is_instance_valid(hover_preview): return
	hover_preview.visible = false
	if not can_interact(): return
	var data = get_viewport().gui_get_drag_data()
	var entry = selected if placement_armed else null
	var offset := Vector2i.ZERO
	if data is Dictionary and data.has("entry"):
		entry = data.entry
		offset = data.get("grab_offset",Vector2i.ZERO)
	if entry==null or entry not in draft.builds[0].owned: return
	var grid: Control = panel.get_node("Grid")
	# Explicit grid coordinates also let headless GUI tests exercise the same renderer.
	var pos: Vector2 = grid.get_local_mouse_position() if grid_position==Vector2.INF else grid_position
	if not Rect2(Vector2.ZERO,Vector2(360,360)).has_point(pos): return
	var anchor := Vector2i(floori(pos.x/60),floori(pos.y/60))-offset
	hover_preview.position = Vector2(anchor)*60
	hover_preview.shape = draft.shape_of(entry)
	hover_preview.tint = Color(.5,1,.85,.3) if draft.fits(0,entry,anchor,entry) else Color(1,.3,.22,.35)
	hover_preview.visible = true
	hover_preview.queue_redraw()
