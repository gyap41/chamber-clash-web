extends CanvasLayer
const Grid = preload("res://scripts/game/build_grid.gd")
const Footprint = preload("res://scripts/ui/item_footprint.gd")
const Widgets = preload("res://scripts/ui/hud_widgets.gd")
const Cell = preload("res://scripts/ui/relic_grid_cell.gd")
const Chip = preload("res://scripts/ui/relic_chip.gd")
const Tray = preload("res://scripts/ui/relic_tray.gd")
const Weapons = preload("res://scripts/catalog/weapon_catalog.gd")
const Relics = preload("res://scripts/catalog/relic_catalog.gd")
const Art = preload("res://scripts/ui/hud_assets.gd")
signal close_requested
var on_change: Callable
var draft
var selected = null
var body: Control
var footprint
var detail: Label
var message := "装備を選んでマスへ配置。控えへドラッグすると解除できます。"
func _ready() -> void:
	layer = 30
	body = Control.new()
	body.name = "Root"
	body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	body.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(body)
	refresh()
func info(entry) -> Dictionary:
	return Weapons.definition(draft.gun_id(entry)) if draft.is_gun(entry) else Relics.definition(draft.relic_id(entry))
func select(entry) -> void:
	selected = entry
	var data := info(entry)
	footprint.shape = draft.shape_of(entry)
	footprint.visible = true
	footprint.queue_redraw()
	detail.text = str(data.name)+" ／ %dマス\n" % draft.shape_of(entry).size()+str(data.get("desc",""))+"\n\n選択 → 空いているマスをクリックで配置"
func commit_layout() -> bool:
	if on_change.is_valid() and on_change.call(): return true
	message = "変更できません。配置と所持品を確認してください。"
	return false
func place(entry, cell: Vector2i) -> bool:
	var success := false
	if not draft.place(0,entry,cell):
		message = "配置できません：形・空きマス・開放範囲を確認してください。"
	else:
		success = commit_layout()
		if success: message = "配置を変更しました。装備に反映済みです。"
		selected = null
	refresh()
	return success
func remove(entry) -> bool:
	if entry not in draft.builds[0].equipped: return false
	var success := false
	if not draft.toggle(0,entry): message = "控えが満杯です。先に控えの装備をバッグへ配置してください。"
	else:
		success = commit_layout()
		if success: message = "控えへ戻しました。装備に反映済みです。"
		selected = null
	refresh()
	return success
func click_cell(cell: Vector2i) -> void:
	if selected != null: place(selected,cell); return
	var occupied: Dictionary = draft.occupied_cells(0)
	if occupied.has(cell): select(occupied[cell])
func add_art(parent: Control, entry, bounds: Rect2) -> void:
	var image := TextureRect.new()
	image.texture = Weapons.art(draft.gun_id(entry)) if draft.is_gun(entry) else Art.texture("relic_%02d" % draft.relic_id(entry))
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.position = bounds.position
	image.size = bounds.size
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(image)
func refresh() -> void:
	for child in body.get_children(): body.remove_child(child); child.queue_free()
	var shade := ColorRect.new()
	shade.color = Color(0,0,0,.72)
	shade.size = Vector2(1120,800)
	body.add_child(shade)
	var panel := Widgets.box(body,"Bag",Rect2(80,110,960,570))
	Widgets.label(panel,"Title",Rect2(24,15,870,34),24).text = "携帯工房 ／ 装備の整理（探索停止中）"
	Widgets.label(panel,"Help",Rect2(24,54,910,35),15).text = message
	Widgets.label(panel,"Equipped",Rect2(24,95,330,28),18).text = "バッグ ／ 使用 %d / %d マス" % [draft.occupied_cells(0).size(),draft.usable_cells(0).size()]
	build_grid(panel)
	build_reserve(panel)
	build_details(panel)
	Widgets.button(panel,"Unequip",Rect2(662,410,270,40),"選択した装備を控えへ",func():
		if selected != null: remove(selected))
	Widgets.button(panel,"Close",Rect2(750,510,182,40),"閉じる ／ Esc",func(): close_requested.emit())
	Widgets.label(panel,"Controls",Rect2(24,510,710,35),14).text = "変更は即時反映  ・  Tab / Esc：閉じる  ・  ドラッグ／クリックで配置"
	if selected != null: select(selected)

func build_grid(panel: Control) -> void:
	var grid := GridContainer.new()
	grid.name = "Grid"
	grid.columns = Grid.MAX_GRID_SIZE.x
	grid.position = Vector2(24,130)
	grid.add_theme_constant_override("h_separation",3)
	grid.add_theme_constant_override("v_separation",3)
	panel.add_child(grid)
	var occupied: Dictionary = draft.occupied_cells(0)
	var usable: Dictionary = draft.usable_cells(0)
	for y in range(Grid.MAX_GRID_SIZE.y):
		for x in range(Grid.MAX_GRID_SIZE.x):
			var pos := Vector2i(x,y)
			var cell := Cell.new()
			cell.name = "Cell_%d_%d" % [x,y]
			cell.inventory_state = draft
			cell.cell = pos
			cell.custom_minimum_size = Vector2(48,48)
			cell.on_drop = place
			cell.on_click = click_cell
			var style := StyleBoxFlat.new()
			style.bg_color = Color("283b44") if usable.has(pos) else Color("11171a")
			style.border_color = Color("64777c")
			style.set_border_width_all(1)
			if occupied.has(pos):
				style.bg_color = Color("30758a") if draft.is_gun(occupied[pos]) else Color(info(occupied[pos]).color).darkened(.5)
				style.border_color = style.bg_color.lightened(.4)
			cell.add_theme_stylebox_override("panel",style)
			grid.add_child(cell)
			if occupied.has(pos):
				var entry = occupied[pos]
				var chip := Chip.new()
				chip.entry = entry
				chip.grab_offset = pos-draft.builds[0].positions[entry]
				chip.on_drag_start = select
				chip.tooltip_text = str(info(entry).name)+" ／ %dマス\n" % draft.shape_of(entry).size()+str(info(entry).get("desc",""))
				for state in ["normal","hover","pressed"]: chip.add_theme_stylebox_override(state,StyleBoxEmpty.new())
				chip.position = Vector2(1,1)
				chip.size = Vector2(46,46)
				chip.pressed.connect(click_cell.bind(pos))
				cell.add_child(chip)
				if draft.builds[0].positions[entry] == pos: add_art(chip,entry,Rect2(4,4,38,38))
				preload("res://scripts/ui/item_grid_appearance.gd").join_cells(cell,style,occupied,pos,entry,48,3,true)
			elif not usable.has(pos): Widgets.label(cell,"Locked",Rect2(13,9,25,30),21).text = "×"

func build_reserve(panel: Control) -> void:
	Widgets.label(panel,"ReserveTitle",Rect2(365,95,270,28),18).text = "控え %d / %d" % [draft.reserve_items(0).size(),Grid.RESERVE_CAPACITY]
	var tray := Tray.new()
	tray.name = "Reserve"
	tray.position = Vector2(360,130)
	tray.size = Vector2(280,355)
	tray.on_drop = remove
	panel.add_child(tray)
	var reserve: Array = draft.reserve_items(0)
	for i in range(reserve.size()):
		var entry = reserve[i]
		var chip := Chip.new()
		chip.entry = entry
		chip.position = Vector2(6,i*43+4)
		chip.size = Vector2(268,40)
		chip.text = "       "+str(info(entry).name)+" [%dマス]" % draft.shape_of(entry).size()
		chip.add_theme_font_size_override("font_size",14)
		chip.alignment = HORIZONTAL_ALIGNMENT_LEFT
		chip.tooltip_text = str(info(entry).name)+"\n"+str(info(entry).get("desc",""))
		chip.on_drag_start = select
		chip.on_reserve_drop = remove
		chip.pressed.connect(select.bind(entry))
		tray.add_child(chip)
		add_art(chip,entry,Rect2(6,3,32,32))

func build_details(panel: Control) -> void:
	detail = Widgets.label(panel,"Detail",Rect2(662,130,274,210),16)
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.text = "装備を選ぶと詳細を表示します。\n\n控えの武器の弾薬・モード・待ち時間は保持されます。\n装備の着脱でHPは回復しません。"
	footprint = Footprint.new()
	footprint.position = Vector2(680,350)
	footprint.size = Vector2(92,48)
	footprint.visible = false
	panel.add_child(footprint)
