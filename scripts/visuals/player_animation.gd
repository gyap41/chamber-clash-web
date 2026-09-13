extends Node2D
const Visuals = preload("res://scripts/catalog/weapon_visual_catalog.gd")
var reload_event: Dictionary = {}
const Rig = preload("res://scripts/visuals/character_rig.gd")
const Directions = preload("res://scripts/visuals/character_direction.gd")
const TRAIL = preload("res://assets/first-workshop/trail.png")
var animation_name := "idle"
var animation_frame := 0
var body_facing := 1
var body_back := false
var body_view := "front"
var move_phase := 0.0
var roll_afterglow := 0.0
# Uses the editable Sprite as the source; its transform/frame remain untouched.
var elapsed := 0.0
var walk := 0.0
var moving := false
var recoil := 0.0
var muzzle := 0.0
var pose := Transform2D.IDENTITY
var leg_step := 0.0
var orbit_positions: Array[Vector2] = []
@onready var player = get_parent()
@onready var source: Sprite2D = player.get_node("Sprite")
@onready var weapon: Node2D = player.get_node("Weapon")
var weapon_base := Transform2D.IDENTITY

func _ready() -> void:
	weapon_base = weapon.transform
	source.hide()

func reset() -> void:
	reload_event.clear()
	elapsed = 0.0
	walk = 0.0
	moving = false
	recoil = 0.0
	muzzle = 0.0
	move_phase = 0.0
	roll_afterglow = 0.0
	body_back = false
	body_view = "front"
	body_facing = 1

func advance(dt: float, has_movement: bool) -> void:
	roll_afterglow = .05 if animation_name == "roll" and player.state.roll <= 0 else maxf(0.0,roll_afterglow-dt)
	elapsed += dt
	moving = has_movement
	if moving: walk += dt*14.0
	if moving: move_phase += dt*14.0*player.effective_move_speed()/205.0
	recoil = maxf(0.0,recoil-dt*9.0)
	muzzle = maxf(0.0,muzzle-dt)

func fire() -> void:
	recoil = 1.0
	muzzle = .075
	refresh()

func refresh() -> void:
	var p: Dictionary = player.state
	var walking: bool = moving and p.roll <= 0.0
	animation_name = "move" if walking else "idle"
	animation_frame = floori(move_phase)%6 if walking else floori(elapsed*3.0)%4
	body_facing = -1 if cos(p.angle) < 0 else 1
	if player.char_id >= 0 and p.roll > 0:
		animation_name = "roll"
		animation_frame = clampi(floori((1.0-p.roll/player.dodge_duration)*6.0),0,5)
		body_facing = -1 if p.dir.x < 0 else 1
	if player.char_id >= 0:
		var direction: Vector2 = p.dir if p.roll > 0 else Vector2.from_angle(p.angle)
		body_view = Directions.select(direction,body_view)
		body_back = body_view == "back"
		body_facing = -1 if body_view == "left" else 1
		if walking and p.dir.dot(Vector2.from_angle(p.angle)) < -.2:
			animation_frame = (6-animation_frame)%6 # Backpedal without reversing aim.
	leg_step = sin(walk)*4.0 if walking else 0.0
	var bob: float = absf(cos(walk))*2.0 if walking else sin(elapsed*2.0+(1 if player.name == "P2" else 0))*.5
	if player.char_id >= 0: bob = 0.0 # Fixed rigs provide their own small body motion.
	pose = Transform2D(0.0,Vector2(-cos(p.angle)*recoil*2.0,-bob))
	if p.roll > 0.0 and player.char_id < 0:
		pose *= Transform2D((player.dodge_duration-p.roll)/player.dodge_duration*TAU,Vector2(1,.8),0.0,Vector2.ZERO)
	weapon.transform = pose*Transform2D(p.angle,Vector2.ZERO)*Transform2D(0.0,Vector2(-recoil*3.0,0))*weapon_base
	if player.char_id >= 0 and p.reload > 0 and not reload_event.is_empty():
		var progress: float = clampf(1.0-p.reload/maxf(float(reload_event.duration),.001),0,1)
		var style: String = str(Visuals.profile(int(reload_event.weapon)).get("reload_style","mechanical"))
		var tilt: float = sin(progress*PI)*(.65 if style == "mechanical" else .15)*(-1 if cos(p.angle)<0 else 1)
		weapon.transform = pose*Transform2D(p.angle+tilt,Vector2(0,-3*sin(progress*PI)))*weapon_base
	weapon.modulate.a = .55 if p.inv > 0 and int(elapsed*22)%2 else 1.0
	if player.char_id >= 0:
		weapon.visible = player.has_weapon() and p.roll <= 0
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		weapon.z_index = -1 if body_back else 1
		weapon.position += Vector2(0,8) # Grip below the compact character's large face.
		player.get_node("Aim").visible = false # Painted weapon supplies the silhouette/aim cue.
	else:
		weapon.visible = player.has_weapon()
		texture_filter = CanvasItem.TEXTURE_FILTER_PARENT_NODE
		weapon.z_index = 0
		player.get_node("Aim").visible = true
	orbit_positions.clear()
	for i in range(player.relics.size()):
		var angle := elapsed*.6+i*TAU/3.0
		orbit_positions.append(Vector2(cos(angle)*32.0,sin(angle)*14.0+10.0))
	queue_redraw()

func _draw() -> void:
	if player.state.is_empty() or source.texture == null: return
	var p: Dictionary = player.state
	if player.char_id >= 0:
		draw_set_transform(Vector2(0,15),0,Vector2(1,.25))
		draw_circle(Vector2.ZERO,16,Color(0.04,0.06,0.06,.25))
	var walking: bool = moving and p.roll <= 0.0
	var facing := Transform2D(0.0,Vector2(-1 if cos(p.angle)<0 else 1,1),0.0,Vector2.ZERO)
	var tilt := Transform2D(sin(walk)*.035 if walking else 0.0,Vector2.ZERO)
	draw_set_transform_matrix(pose*facing*tilt*source.transform)
	var cell := source.texture.get_size()/Vector2(source.hframes,source.vframes)
	var origin := Vector2(source.frame_coords)*cell
	var dest := source.get_rect()
	var color := source.modulate
	color.a *= .55 if p.inv > 0 and int(elapsed*22)%2 else 1.0
	if player.char_id >= 0:
		if p.roll > 0 or roll_afterglow > 0:
			draw_set_transform(Vector2(0,14),p.dir.angle())
			draw_texture_rect(TRAIL,Rect2(-43,-13,42,25),false,Color(1,1,1,.5 if p.roll > 0 else roll_afterglow*10))
		draw_set_transform_matrix(pose*Transform2D(0.0,Vector2(body_facing,1),0.0,Vector2.ZERO))
		var phase := move_phase
		if p.dir.dot(Vector2.from_angle(p.angle)) < -.2: phase = -phase
		var local_direction: Vector2 = p.dir*Vector2(body_facing,1)
		var roll_progress: float = 1.0-p.roll/player.dodge_duration if p.roll > 0 else -1.0
		Rig.render(self,player.char_id,pose*Transform2D(0.0,Vector2(body_facing,1),0.0,Vector2.ZERO),body_back,walking,phase,local_direction,roll_progress,elapsed,color,body_view)
	else:
		for leg in range(2):
			var shift := leg_step if leg == 0 else -leg_step
			var local_shift := Vector2(shift*.3,shift*.55)/source.scale
			var size := Vector2(cell.x/2,cell.y*.28)
			var offset := Vector2(cell.x*leg/2,cell.y*.72)
			draw_texture_rect_region(source.texture,Rect2(dest.position+offset+local_shift,size),Rect2(origin+offset,size),color)
		draw_texture_rect_region(source.texture,Rect2(dest.position,Vector2(cell.x,cell.y*.72)),Rect2(origin,Vector2(cell.x,cell.y*.72)),color)
	draw_set_transform_matrix(Transform2D.IDENTITY)
	if not reload_event.is_empty() and p.reload > 0 and p.hp > 0 and p.roll <= 0:
		var spec := Visuals.profile(int(reload_event.weapon))
		var progress := clampf(1.0-float(p.reload)/maxf(float(reload_event.duration),.001),0,1)
		var tint := Color(spec.get("color","#ffffff"));tint.a = .65
		draw_set_transform_matrix(weapon.transform)
		var center := Vector2(15,0)
		match str(spec.get("reload_style","mechanical")):
			"charge": draw_arc(center,10,0,TAU*progress,24,tint,1.5,true)
			"rune":
				for i in range(4):
					var v := Vector2.from_angle(i*PI/2+progress*TAU)*(14-7*progress)
					draw_line(center+v,center+v*.55,tint,1.5,true)
			_: draw_line(center+Vector2(-3,5),center+Vector2(-3,5+7*sin(progress*PI)),tint,3.0)
		draw_set_transform_matrix(Transform2D.IDENTITY)
	if 3 in player.relics and p.shield <= 0.0:
		draw_arc(Vector2(0,-7),33,0,TAU,64,Color("ffe2a0aa"),2.0,true)
	for i in range(orbit_positions.size()):
		var points := PackedVector2Array()
		var angle := elapsed*.6+i*TAU/3.0
		for n in range(10):
			points.append(orbit_positions[i]+Vector2.from_angle(-PI/2+n*PI/5+angle)*(3.0 if n%2==0 else 1.35))
		draw_colored_polygon(points,Color(player.Relics.definition(player.relics[i]).color))

func weapon_event(event: Dictionary) -> void:
	if event.kind == "reload_start": reload_event = event.duplicate()
	elif event.kind in ["reload_cancel","reload_complete"] and int(event.token) == int(reload_event.get("token",-1)):
		reload_event.clear()
