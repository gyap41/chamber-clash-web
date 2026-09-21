extends Node2D
const Visuals = preload("res://scripts/catalog/weapon_visual_catalog.gd")
const Snapshot = preload("res://scripts/visuals/actor_visual_state.gd")
var snapshot: Snapshot
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
@onready var source: Sprite2D = get_node("../Sprite")
@onready var weapon: Node2D = get_node("../Weapon")
@onready var aim: Node2D = get_node("../Aim")
@onready var state_machine = $StateMachine
var weapon_base := Transform2D.IDENTITY

func _ready() -> void:
	weapon_base = weapon.transform
	source.hide()

func reset() -> void:
	snapshot = null
	state_machine.reset()
	animation_name = "idle"
	animation_frame = 0
	pose = Transform2D.IDENTITY
	leg_step = 0.0
	orbit_positions.clear()
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

func present(value: Snapshot, dt: float = 0.0) -> void:
	snapshot = value
	roll_afterglow = .05 if animation_name == "roll" and snapshot.dodge_remaining <= 0 else maxf(0.0,roll_afterglow-dt)
	moving = snapshot.moving and snapshot.alive
	if snapshot.alive: elapsed += dt
	if moving:
		walk += dt*14.0
		move_phase += dt*14.0*snapshot.move_speed/205.0
	recoil = maxf(0.0,recoil-dt*9.0)
	muzzle = maxf(0.0,muzzle-dt)
	refresh(dt)

func fire() -> void:
	if snapshot == null or not snapshot.alive: return
	recoil = 1.0
	muzzle = .075
	refresh()
	state_machine.restart_fire()

func refresh(dt: float = 0.0) -> void:
	if snapshot == null: return
	state_machine.present(snapshot,recoil > 0,dt)
	animation_name = str(state_machine.body_state)
	var walking: bool = animation_name == "move"
	var rolling: bool = animation_name == "roll"
	animation_frame = floori(move_phase)%6 if walking else floori(elapsed*3.0)%4
	body_facing = -1 if cos(snapshot.angle) < 0 else 1
	if snapshot.character_id >= 0 and rolling:
		animation_name = "roll"
		animation_frame = clampi(floori((1.0-snapshot.dodge_remaining/snapshot.dodge_duration)*6.0),0,5)
		body_facing = -1 if snapshot.direction.x < 0 else 1
	if snapshot.character_id >= 0:
		var direction: Vector2 = snapshot.direction if rolling else Vector2.from_angle(snapshot.angle)
		body_view = Directions.select(direction,body_view)
		body_back = body_view == "back"
		body_facing = -1 if body_view == "left" else 1
		if walking and snapshot.direction.dot(Vector2.from_angle(snapshot.angle)) < -.2:
			animation_frame = (6-animation_frame)%6 # Backpedal without reversing aim.
	leg_step = sin(walk)*4.0 if walking else 0.0
	var bob: float = absf(cos(walk))*2.0 if walking else sin(elapsed*2.0+snapshot.idle_offset)*.5
	if snapshot.character_id >= 0: bob = 0.0 # Fixed rigs provide their own small body motion.
	pose = Transform2D(0.0,Vector2(-cos(snapshot.angle)*recoil*2.0,-bob))
	if rolling and snapshot.character_id < 0:
		pose *= Transform2D((snapshot.dodge_duration-snapshot.dodge_remaining)/snapshot.dodge_duration*TAU,Vector2(1,.8),0.0,Vector2.ZERO)
	var part_color := source.modulate
	part_color.a *= .55 if snapshot.invulnerable and int(elapsed*22)%2 else 1.0
	state_machine.parts.present(snapshot.character_id,body_view,
		pose*Transform2D(0.0,Vector2(body_facing,1),0.0,Vector2.ZERO),
		snapshot.direction*Vector2(body_facing,1),part_color,state_machine.body_state,
		snapshot.move_speed/205.0,dt)
	weapon.transform = pose*Transform2D(snapshot.angle,Vector2.ZERO)*Transform2D(0.0,Vector2(-recoil*3.0,0))*weapon_base
	if snapshot.character_id >= 0 and state_machine.weapon_state == &"reload" and not reload_event.is_empty():
		var progress: float = clampf(1.0-snapshot.reload_remaining/maxf(float(reload_event.duration),.001),0,1)
		var style: String = str(Visuals.profile(int(reload_event.weapon)).get("reload_style","mechanical"))
		var tilt: float = sin(progress*PI)*(.65 if style == "mechanical" else .15)*(-1 if cos(snapshot.angle)<0 else 1)
		weapon.transform = pose*Transform2D(snapshot.angle+tilt,Vector2(0,-3*sin(progress*PI)))*weapon_base
	weapon.modulate.a = .55 if snapshot.invulnerable and int(elapsed*22)%2 else 1.0
	if snapshot.character_id >= 0:
		weapon.visible = snapshot.weapon_visible()
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		weapon.z_index = -1 if body_back else 1
		# Keep the whole actor in one depth band when furniture is Y-sorted.
		if get_parent().get_parent() is Node2D and get_parent().get_parent().y_sort_enabled:
			weapon.z_index = 0
			var actor := get_parent()
			var body_index: int = get_index()
			if body_back and weapon.get_index() > body_index: actor.move_child(weapon,body_index)
			elif not body_back and weapon.get_index() < body_index: actor.move_child(weapon,body_index)
		weapon.position += Vector2(0,8) # Grip below the compact character's large face.
		weapon.position += state_machine.parts.grip_offset()
		aim.visible = false # Painted weapon supplies the silhouette/aim cue.
	else:
		weapon.visible = snapshot.weapon_visible()
		texture_filter = CanvasItem.TEXTURE_FILTER_PARENT_NODE
		weapon.z_index = 0
		aim.visible = true
	orbit_positions.clear()
	for i in range(snapshot.relic_colors.size()):
		var angle := elapsed*.6+i*TAU/3.0
		orbit_positions.append(Vector2(cos(angle)*32.0,sin(angle)*14.0+10.0))
	queue_redraw()

func _draw() -> void:
	if snapshot == null or source.texture == null: return
	if snapshot.character_id >= 0:
		draw_set_transform(Vector2(0,15),0,Vector2(1,.25))
		draw_circle(Vector2.ZERO,16,Color(0.04,0.06,0.06,.25))
	var walking: bool = animation_name == "move"
	var rolling: bool = animation_name == "roll"
	var facing := Transform2D(0.0,Vector2(-1 if cos(snapshot.angle)<0 else 1,1),0.0,Vector2.ZERO)
	var tilt := Transform2D(sin(walk)*.035 if walking else 0.0,Vector2.ZERO)
	draw_set_transform_matrix(pose*facing*tilt*source.transform)
	var cell := source.texture.get_size()/Vector2(source.hframes,source.vframes)
	var origin := Vector2(source.frame_coords)*cell
	var dest := source.get_rect()
	var color := source.modulate
	color.a *= .55 if snapshot.invulnerable and int(elapsed*22)%2 else 1.0
	if snapshot.character_id >= 0:
		if rolling or roll_afterglow > 0:
			draw_set_transform(Vector2(0,14),snapshot.direction.angle())
			draw_texture_rect(TRAIL,Rect2(-43,-13,42,25),false,Color(1,1,1,.5 if rolling else roll_afterglow*10))
		draw_set_transform_matrix(pose*Transform2D(0.0,Vector2(body_facing,1),0.0,Vector2.ZERO))
		var phase := move_phase
		if snapshot.direction.dot(Vector2.from_angle(snapshot.angle)) < -.2: phase = -phase
		var local_direction: Vector2 = snapshot.direction*Vector2(body_facing,1)
		var roll_progress: float = snapshot.dodge_progress() if rolling else -1.0
		# Idle/movement now use the editable Sprite parts. Dedicated dodge art
		# remains the original drawing, synchronized to combat's dodge progress.
		if rolling:
			Rig.render(self,snapshot.character_id,pose*Transform2D(0.0,Vector2(body_facing,1),0.0,Vector2.ZERO),body_back,walking,phase,local_direction,roll_progress,elapsed,color,body_view)
	else:
		for leg in range(2):
			var shift := leg_step if leg == 0 else -leg_step
			var local_shift := Vector2(shift*.3,shift*.55)/source.scale
			var size := Vector2(cell.x/2,cell.y*.28)
			var offset := Vector2(cell.x*leg/2,cell.y*.72)
			draw_texture_rect_region(source.texture,Rect2(dest.position+offset+local_shift,size),Rect2(origin+offset,size),color)
		draw_texture_rect_region(source.texture,Rect2(dest.position,Vector2(cell.x,cell.y*.72)),Rect2(origin,Vector2(cell.x,cell.y*.72)),color)
	draw_set_transform_matrix(Transform2D.IDENTITY)
	if not reload_event.is_empty() and state_machine.weapon_state == &"reload" and snapshot.alive and not rolling:
		var spec := Visuals.profile(int(reload_event.weapon))
		var progress := clampf(1.0-float(snapshot.reload_remaining)/maxf(float(reload_event.duration),.001),0,1)
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
	if snapshot.shield_visible:
		draw_arc(Vector2(0,-7),33,0,TAU,64,Color("ffe2a0aa"),2.0,true)
	for i in range(orbit_positions.size()):
		var points := PackedVector2Array()
		var angle := elapsed*.6+i*TAU/3.0
		for n in range(10):
			points.append(orbit_positions[i]+Vector2.from_angle(-PI/2+n*PI/5+angle)*(3.0 if n%2==0 else 1.35))
		draw_colored_polygon(points,snapshot.relic_colors[i])

func weapon_event(event: Dictionary) -> void:
	if event.kind == "reload_start": reload_event = event.duplicate()
	elif event.kind in ["reload_cancel","reload_complete"] and int(event.token) == int(reload_event.get("token",-1)):
		reload_event.clear()
