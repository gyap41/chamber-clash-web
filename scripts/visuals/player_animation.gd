extends Node2D
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
	elapsed = 0.0
	walk = 0.0
	moving = false
	recoil = 0.0
	muzzle = 0.0

func advance(dt: float, has_movement: bool) -> void:
	elapsed += dt
	moving = has_movement
	if moving: walk += dt*14.0
	recoil = maxf(0.0,recoil-dt*9.0)
	muzzle = maxf(0.0,muzzle-dt)

func fire() -> void:
	recoil = 1.0
	muzzle = .075
	refresh()

func refresh() -> void:
	var p: Dictionary = player.state
	var walking: bool = moving and p.roll <= 0.0
	leg_step = sin(walk)*4.0 if walking else 0.0
	var bob: float = absf(cos(walk))*2.0 if walking else sin(elapsed*2.0+(1 if player.name == "P2" else 0))*.5
	pose = Transform2D(0.0,Vector2(-cos(p.angle)*recoil*2.0,-bob))
	if p.roll > 0.0:
		pose *= Transform2D((player.dodge_duration-p.roll)/player.dodge_duration*TAU,Vector2(1,.8),0.0,Vector2.ZERO)
	weapon.transform = pose*Transform2D(p.angle,Vector2.ZERO)*Transform2D(0.0,Vector2(-recoil*3.0,0))*weapon_base
	weapon.modulate.a = .55 if p.inv > 0 and int(elapsed*22)%2 else 1.0
	orbit_positions.clear()
	for i in range(player.relics.size()):
		var angle := elapsed*.6+i*TAU/3.0
		orbit_positions.append(Vector2(cos(angle)*32.0,sin(angle)*14.0+10.0))
	queue_redraw()

func _draw() -> void:
	if player.state.is_empty() or source.texture == null: return
	var p: Dictionary = player.state
	var walking: bool = moving and p.roll <= 0.0
	var facing := Transform2D(0.0,Vector2(-1 if cos(p.angle)<0 else 1,1),0.0,Vector2.ZERO)
	var tilt := Transform2D(sin(walk)*.035 if walking else 0.0,Vector2.ZERO)
	draw_set_transform_matrix(pose*facing*tilt*source.transform)
	var cell := source.texture.get_size()/Vector2(source.hframes,source.vframes)
	var origin := Vector2(source.frame_coords)*cell
	var dest := source.get_rect()
	var color := source.modulate
	color.a *= .55 if p.inv > 0 and int(elapsed*22)%2 else 1.0
	for leg in range(2):
		var shift := leg_step if leg == 0 else -leg_step
		var local_shift := Vector2(shift*.3,shift*.55)/source.scale
		var size := Vector2(cell.x/2,cell.y*.28)
		var offset := Vector2(cell.x*leg/2,cell.y*.72)
		draw_texture_rect_region(source.texture,Rect2(dest.position+offset+local_shift,size),Rect2(origin+offset,size),color)
	draw_texture_rect_region(source.texture,Rect2(dest.position,Vector2(cell.x,cell.y*.72)),Rect2(origin,Vector2(cell.x,cell.y*.72)),color)
	draw_set_transform_matrix(Transform2D.IDENTITY)
	if muzzle > 0 and p.roll <= 0:
		draw_set_transform_matrix(weapon.transform)
		var flash := Color("b4edff") if player.definition().get("rail",false) else Color("fff0b0")
		flash.a = minf(1.0,muzzle/.035)
		draw_line(Vector2(26,0),Vector2(40+recoil*8,0),flash,4)
		for sign_value in [-1,1]: draw_line(Vector2(27,0),Vector2(36,sign_value*7),flash,2)
		draw_set_transform_matrix(Transform2D.IDENTITY)
	if 3 in player.relics and p.shield <= 0.0:
		draw_arc(Vector2(0,-7),33,0,TAU,64,Color("ffe2a0aa"),2.0,true)
	for i in range(orbit_positions.size()):
		var points := PackedVector2Array()
		var angle := elapsed*.6+i*TAU/3.0
		for n in range(10):
			points.append(orbit_positions[i]+Vector2.from_angle(-PI/2+n*PI/5+angle)*(3.0 if n%2==0 else 1.35))
		draw_colored_polygon(points,Color(player.Relics.definition(player.relics[i]).color))
