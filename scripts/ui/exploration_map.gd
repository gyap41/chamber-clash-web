extends CanvasLayer
const Widgets = preload("res://scripts/ui/hud_widgets.gd")
signal close_requested
var floor_data: Dictionary
var current := ""
var visited: Dictionary
var room_states: Dictionary
func _ready() -> void:
	layer = 25
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var shade := ColorRect.new()
	shade.color = Color(0,0,0,.78)
	shade.size = Vector2(1120,800)
	root.add_child(shade)
	var panel := Widgets.box(root,"Map",Rect2(100,120,920,560))
	Widgets.label(panel,"Title",Rect2(24,16,870,34),23).text = "第1階層 ／ 訪問 %d / %d部屋" % [visited.size(),floor_data.rooms.size()]
	Widgets.label(panel,"Legend",Rect2(24,57,870,30),15).text = "金枠：現在地　青：訪問済み　灰：隣接する未訪問　✓：攻略済み"
	Widgets.label(panel,"Seed",Rect2(24,510,650,28),15).text = "seed %d ／ 生成版 %d　　ショップ・ボスは配置のみの試作" % [floor_data.seed,floor_data.version]
	Widgets.button(panel,"Close",Rect2(720,506,176,38),"M / Esc：閉じる",func(): close_requested.emit())
	var diagram := Control.new()
	diagram.position = Vector2(24,102)
	diagram.size = Vector2(872,380)
	diagram.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(diagram)
	diagram.draw.connect(func(): draw_map(diagram))
func visible_rooms() -> Dictionary:
	var visible := visited.duplicate()
	for id in visited:
		for door in floor_data.catalog[id].doors: visible[door.target_room] = true
	return visible
func draw_map(canvas: Control) -> void:
	var visible := visible_rooms()
	var low := Vector2(100,100)
	var high := Vector2(-100,-100)
	for id in floor_data.rooms:
		var cell := Vector2(floor_data.rooms[id].cell)
		low = low.min(cell)
		high = high.max(cell)
	var span := high-low+Vector2.ONE
	var pitch := minf(95,minf(canvas.size.x/span.x,canvas.size.y/span.y))
	var origin := (canvas.size-(span-Vector2.ONE)*pitch)*.5-low*pitch
	for id in visible:
		var point := origin+Vector2(floor_data.rooms[id].cell)*pitch
		for door in floor_data.catalog[id].doors:
			if visible.has(door.target_room) and (visited.has(id) or visited.has(door.target_room)):
				canvas.draw_line(point,origin+Vector2(floor_data.rooms[door.target_room].cell)*pitch,Color("73828a"),2)
	for id in visible:
		var point := origin+Vector2(floor_data.rooms[id].cell)*pitch
		var rect := Rect2(point-Vector2(pitch*.4,18),Vector2(pitch*.8,36))
		canvas.draw_rect(rect,Color("30566a") if visited.has(id) else Color("30363b"))
		canvas.draw_rect(rect,Color("ffd37a") if id == current else Color("87949c"),false,3 if id == current else 1)
		var label: String = "未訪問"
		if visited.has(id):
			label = {"start":"入口","normal":"作業室","treasure":"宝箱","shop":"店","boss":"ボス"}[floor_data.rooms[id].role]
			if room_states.get(id,{}).get("encounter","") == "cleared": label += "✓"
			elif room_states.get(id,{}).get("reward",{}).get("state","") == "empty": label += "✓"
		var font := ThemeDB.fallback_font
		var font_size := 13
		if pitch < 55:
			label = label.replace("作業室","室").replace("未訪問","?")
			font_size = 11
		canvas.draw_string(font,point+Vector2(-font.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x*.5,5),label,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size)
