extends CanvasLayer
# Floor map (version 2, 2026-09-30, docs/planning/FLOOR_EXPANSION_PLAN.md stage 2). Each room is drawn from its
# real floor outline, centred in its floor cell, with corridors between the actual door positions. Visited rooms
# show their role icon; rooms seen through a door are dim outlines with "?" until entered. Only what the player
# has seen decides the framing, so the map never hints at the unexplored extent of the floor.
const Widgets = preload("res://scripts/ui/hud_widgets.gd")
const Chest = preload("res://scripts/world/exploration_chest.gd")
const CAMPFIRE = preload("res://assets/stages/ashen-foundry-v2/props/campfire.png")
const AREA := Rect2(40,92,1040,628)
const MAX_SCALE := .085 # World px to map px: a 1440 px room is at most about 122 px wide.
const CELL_GAP := 1.3 # Cell pitch relative to the typical room, leaving room for corridors.
const OUTLINE := 3.0
const COLORS := {"visited":Color("33477d"),"current":Color("4d67b3"),"unknown":Color("1a2130"),
	"edge":Color("dfe6f5"),"unknown_edge":Color("6d7a92"),"corridor":Color("aab6d6"),"marker":Color("ffd35a")}
signal close_requested
signal teleport_requested(room_id: String)
var floor_data: Dictionary
var current := ""
var visited: Dictionary
var room_states: Dictionary
var player_pos := Vector2(-1,-1) # Position in the current room; negative when unknown.
var teleporters: Array = [] # Rooms with an active teleporter, marked on the map.
var teleport_targets: Array = [] # In teleport mode: numbered destinations, chosen by click or number key.
var canvas: Control
var map_scale := 1.0
var origin := Vector2.ZERO
var pitch := Vector2.ONE
var clock := 0.0

func _ready() -> void:
	layer = 25
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	# The paused room stays faintly visible behind the map, as in the reference; the title and legend sit on
	# solid bands so the combat HUD underneath never shows through the text.
	var shade := ColorRect.new()
	shade.color = Color(.02,.03,.06,.9)
	shade.size = Vector2(1120,800)
	root.add_child(shade)
	for band in [Rect2(0,0,1120,78),Rect2(0,726,1120,74)]:
		var bar := ColorRect.new()
		bar.color = Color("080b12")
		bar.position = band.position
		bar.size = band.size
		root.add_child(bar)
		var rule := ColorRect.new()
		rule.color = Color(COLORS.edge,.7)
		rule.position = Vector2(40,band.end.y-2 if band.position.y == 0 else band.position.y)
		rule.size = Vector2(1040,2)
		root.add_child(rule)
	# Clicks on a numbered destination teleport; the buttons added later stay on top of this catcher.
	var catcher := Control.new()
	catcher.size = Vector2(1120,800)
	catcher.mouse_filter = Control.MOUSE_FILTER_STOP if not teleport_targets.is_empty() else Control.MOUSE_FILTER_IGNORE
	catcher.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			for id in teleport_targets:
				if room_rects(id).any(func(rect): return rect.grow(6).has_point(event.position)): teleport_requested.emit(id))
	root.add_child(catcher)
	var title := Widgets.label(root,"Title",Rect2(0,22,1120,40),26)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.text = "第1階層" if teleport_targets.is_empty() else "転送先を選ぶ（番号キーまたはクリック）"
	var count := Widgets.label(root,"Visited",Rect2(40,26,300,30),16)
	count.text = "訪問 %d部屋" % visited.size()
	var legend := Widgets.label(root,"Legend",Rect2(40,738,760,28),15)
	legend.text = "◆現在地　焚き火：入口　箱：宝箱　G：露店　炎：祭壇　剣：試練　髑髏：最奥　◎：転送装置　？：未訪問"
	if floor_data.get("preview",false):
		var note := Widgets.label(root,"Seed",Rect2(40,762,760,24),13)
		note.text = "seed %d ／ 部屋構成の見学・戦闘と報酬なし" % floor_data.seed
	Widgets.button(root,"Close",Rect2(900,736,180,40),"M / Esc：閉じる",func(): close_requested.emit())
	canvas = Control.new()
	canvas.position = Vector2.ZERO
	canvas.size = Vector2(1120,800)
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(canvas)
	canvas.draw.connect(draw_map)
	frame()

func _process(delta: float) -> void:
	clock += delta
	canvas.queue_redraw()

func visible_rooms() -> Dictionary:
	var seen := visited.duplicate()
	for id in visited:
		for door in floor_data.catalog[id].doors: seen[door.target_room] = true
	return seen

func role(id: String) -> String:
	var meta: Dictionary = floor_data.rooms[id]
	return meta.get("map_role",meta.role)

# Cell pitch comes from the ordinary rooms; a larger room (the boss hall) is shrunk to fit its cell.
func frame() -> void:
	var typical := Vector2(600,400)
	for id in floor_data.catalog:
		if role(id) != "boss": typical = typical.max(floor_data.catalog[id].field.field_rect.size)
	pitch = typical*CELL_GAP
	var low := Vector2(INF,INF)
	var high := -low
	for id in visible_rooms():
		var cell := Vector2(floor_data.rooms[id].cell)
		low = low.min(cell)
		high = high.max(cell)
	var span := (high-low+Vector2.ONE)*pitch
	map_scale = minf(MAX_SCALE,minf(AREA.size.x/span.x,AREA.size.y/span.y))
	origin = AREA.get_center()-span*map_scale*.5-low*pitch*map_scale

func room_scale(id: String) -> float:
	var size: Vector2 = floor_data.catalog[id].field.field_rect.size
	return minf(1.0,minf(pitch.x/CELL_GAP/size.x,pitch.y/CELL_GAP/size.y))

# World point inside a room to map coordinates.
func to_map(id: String, point: Vector2) -> Vector2:
	var size: Vector2 = floor_data.catalog[id].field.field_rect.size
	var fit := room_scale(id)
	var corner := Vector2(floor_data.rooms[id].cell)*pitch+(pitch-size*fit)*.5
	return origin+(corner+point*fit)*map_scale

func room_rects(id: String) -> Array:
	var rects: Array = []
	for rect in floor_data.catalog[id].field.floor_regions:
		var a := to_map(id,rect.position)
		rects.append(Rect2(a,to_map(id,rect.end)-a))
	return rects

func room_center(id: String) -> Vector2:
	var bounds := Rect2()
	for rect in room_rects(id): bounds = rect if bounds.size == Vector2.ZERO else bounds.merge(rect)
	return bounds.get_center()

func draw_map() -> void:
	var seen := visible_rooms()
	# Corridors first, from door to door, bending once at the midpoint when the doors are offset.
	var drawn := {}
	for id in seen:
		for door in floor_data.catalog[id].doors:
			var other: String = door.target_room
			if not seen.has(other) or not (visited.has(id) or visited.has(other)): continue
			var key := [id,other]
			key.sort()
			if drawn.has(str(key)): continue
			drawn[str(key)] = true
			var target := door_position(other,door.target_door)
			var start := to_map(id,door.position)
			var finish := to_map(other,target)
			var middle := (start+finish)*.5
			var points := PackedVector2Array([start,Vector2(middle.x,start.y),Vector2(middle.x,finish.y),finish]) if absf(door.direction.x) > 0 else PackedVector2Array([start,Vector2(start.x,middle.y),Vector2(finish.x,middle.y),finish])
			canvas.draw_polyline(points,COLORS.corridor,2.0)
	for id in seen:
		var known: bool = visited.has(id)
		var fill: Color = COLORS.current if id == current else (COLORS.visited if known else COLORS.unknown)
		var edge: Color = COLORS.edge if known else COLORS.unknown_edge
		var rects := room_rects(id)
		# The outline is the union's border: every rectangle grown by the line width, then all fills on top.
		for rect in rects: canvas.draw_rect(rect.grow(OUTLINE if known else 1.5),edge)
		for rect in rects: canvas.draw_rect(rect,fill)
		var center := room_center(id)
		if known: draw_icon(id,center)
		else: draw_text("?",center,20,COLORS.unknown_edge)
		if known and id in teleporters: draw_teleport(id)
	if visited.has(current) and player_pos.x >= 0:
		var point := to_map(current,player_pos)
		var pulse := 1.0+.25*sin(clock*6.0)
		canvas.draw_circle(point,7.0*pulse,Color(COLORS.marker,.35))
		canvas.draw_colored_polygon(PackedVector2Array([point+Vector2(0,-6),point+Vector2(5,0),point+Vector2(0,6),point+Vector2(-5,0)]),COLORS.marker)

func door_position(id: String, door_id: String) -> Vector2:
	for door in floor_data.catalog[id].doors:
		if door.id == door_id: return door.position
	return floor_data.catalog[id].field.field_rect.size*.5

# Number keys choose destinations in the order they are labelled.
func choose(index: int) -> bool:
	if index < 0 or index >= teleport_targets.size(): return false
	teleport_requested.emit(teleport_targets[index])
	return true

func draw_teleport(id: String) -> void:
	var bounds := Rect2()
	for rect in room_rects(id): bounds = rect if bounds.size == Vector2.ZERO else bounds.merge(rect)
	var corner := bounds.position+Vector2(bounds.size.x-12,12)
	canvas.draw_arc(corner,7,0,TAU,16,Color(.55,.85,1),2)
	canvas.draw_circle(corner,3,Color(.7,.9,1))
	var number := teleport_targets.find(id)
	if number >= 0:
		var pulse := .6+.4*sin(clock*5.0)
		canvas.draw_rect(bounds.grow(6),Color(.55,.85,1,pulse),false,3)
		draw_text(str(number+1),bounds.position+Vector2(14,16),18,Color(.75,.92,1))

func draw_icon(id: String, center: Vector2) -> void:
	var cleared: bool = room_states.get(id,{}).get("encounter","") == "cleared"
	match role(id):
		"start":
			var size := Vector2(28,28*CAMPFIRE.get_height()/float(CAMPFIRE.get_width()))
			canvas.draw_texture_rect(CAMPFIRE,Rect2(center-size*.5,size),false)
		"treasure","discovery":
			var opened: bool = room_states.get(id,{}).get("reward",{}).get("state","") == "empty"
			var region: Rect2 = Chest.CHEST_REGIONS[0][3 if opened else 0]
			var size: Vector2 = region.size*(30.0/region.size.x)
			canvas.draw_texture_rect_region(Chest.CHEST_TEXTURES[0],Rect2(center-size*.5,size),region,Color(1,1,1,.55 if opened else 1.0))
		"boss": draw_skull(center,Color(1,1,1,.45) if cleared else Color("f0e4d0"))
		"antechamber": draw_gate(center)
		"shop":
			canvas.draw_circle(center,11,Color("8a5a12"))
			canvas.draw_circle(center,9,Color("f2c14e"))
			draw_text("G",center,14,Color("5a3a08"))
		"altar":
			canvas.draw_rect(Rect2(center+Vector2(-10,0),Vector2(20,9)),Color("c8c0d0"))
			canvas.draw_circle(center+Vector2(0,-5),5,Color(.95,.3,.3) if not room_states.get(id,{}).get("altar",{}).get("used",false) else Color(1,1,1,.3))
		"challenge":
			var tint := Color(1,.8,.35) if room_states.get(id,{}).get("challenge",{}).get("state","idle") != "done" else Color(1,1,1,.4)
			canvas.draw_line(center+Vector2(-9,-9),center+Vector2(9,9),tint,3)
			canvas.draw_line(center+Vector2(9,-9),center+Vector2(-9,9),tint,3)
		_:
			if cleared: draw_text("✓",center,16,Color(.8,.9,1,.55))

func draw_skull(center: Vector2, color: Color) -> void:
	canvas.draw_circle(center+Vector2(0,-3),10,color)
	canvas.draw_rect(Rect2(center+Vector2(-6,3),Vector2(12,8)),color)
	var hollow := Color("1a2130")
	canvas.draw_circle(center+Vector2(-4,-3),3,hollow)
	canvas.draw_circle(center+Vector2(4,-3),3,hollow)
	for x in [-3,0,3]: canvas.draw_line(center+Vector2(x,6),center+Vector2(x,11),hollow,1.5)

func draw_gate(center: Vector2) -> void:
	var color := Color("c8d2e8")
	canvas.draw_arc(center+Vector2(0,-2),8,PI,TAU,12,color,3)
	canvas.draw_line(center+Vector2(-8,-2),center+Vector2(-8,10),color,3)
	canvas.draw_line(center+Vector2(8,-2),center+Vector2(8,10),color,3)

func draw_text(text: String, center: Vector2, size: int, color: Color) -> void:
	var font := ThemeDB.fallback_font
	var width := font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x
	canvas.draw_string(font,center+Vector2(-width*.5,size*.36),text,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)
