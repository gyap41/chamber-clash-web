extends Control
# 2026-10-05: adopted atlas; shared geometry with the reviewed 1120x800 comp.
const SHELL = preload("res://assets/ui/exploration/workshop/shell.png")
const DRIVE = preload("res://assets/ui/exploration/workshop/drive.png")
const POWER = preload("res://assets/ui/exploration/workshop/power.png")
static var parts: Dictionary = {}
var time: float = 0.0
var clock: float = 0.0
var foreground: bool = false
var closing: bool = false
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if parts.is_empty():
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/ui/exploration/workshop/regions.json"))
		for part in data.parts: parts[part.id] = part
func smooth_progress(value: float) -> float:
	var t: float = clampf(value,0,1)
	return t*t*(3-2*t)
func sprite(id: String,rect: Rect2,angle: float = 0,mirror: bool = false,alpha: float = 1,brightness: float = 1) -> void:
	if rect.size.x < .1 or alpha <= 0: return
	var part: Dictionary = parts[id]
	var region: Array = part.region
	var tex: Texture2D = SHELL if part.atlas == "shell.png" else DRIVE if part.atlas == "drive.png" else POWER
	draw_set_transform(rect.get_center(),angle,Vector2(-1 if mirror else 1,1))
	draw_texture_rect_region(tex,Rect2(-rect.size/2,rect.size),Rect2(region[0],region[1],region[2],region[3]),Color(brightness,brightness,brightness,alpha))
	draw_set_transform(Vector2.ZERO)
func frame() -> void:
	var r: Array = parts.body_frame.region
	var xx: Array = [0,120,r[2]-120,r[2]]
	var yy: Array = [0,100,r[3]-100,r[3]]
	var dx: Array = [94,160,960,1026]
	var dy: Array = [135,201,649,715]
	for y in range(3):
		for x in range(3):
			draw_texture_rect_region(SHELL,Rect2(dx[x],dy[y],dx[x+1]-dx[x],dy[y+1]-dy[y]),Rect2(r[0]+xx[x],r[1]+yy[y],xx[x+1]-xx[x],yy[y+1]-yy[y]))
func _draw() -> void:
	if parts.is_empty(): return
	if not foreground:
		sprite("inner_backing",Rect2(106,147,908,555))
		frame()
		return
	var lid: float = smooth_progress((time-.1)/.35)
	var angle: float = lid*96
	var width: float = 456*absf(cos(deg_to_rad(angle)))
	var power: float = .3*smooth_progress(time/.085)+.7*smooth_progress((time-.35)/.25)
	for side in [-1,1]:
		var x: float = 560+side*475
		var points := PackedVector2Array([Vector2(560+side*48,130),Vector2(x,130),Vector2(x,156)])
		draw_polyline(points,Color("776040"),12,true)
		draw_polyline(points,Color(.44,.91,.78,clampf(time/.085,0,1)*.65),2,true)
		sprite("elbow",Rect2(x-10,122,20,25),0,side>0)
		var hinge: float = 104 if side<0 else 1016
		var back: bool = angle>90
		var left: float = (hinge-width if back else hinge) if side<0 else (hinge if back else hinge-width)
		sprite("lid_back" if back else "lid_front",Rect2(left,146,width,554),0,side>0)
		sprite("hinge",Rect2(hinge-9,239,18,35))
		sprite("hinge",Rect2(hinge-9,530,18,35))
		var latch_x: float = 104+width-25-smooth_progress(time/.12)*10 if side<0 else 1016-width+smooth_progress(time/.12)*10
		sprite("latch",Rect2(latch_x,370,25,60),0,side>0,1-lid)
		sprite("shaft",Rect2(x-6,216,28,28),0,side>0)
		sprite("gear_housing",Rect2(x-29,155,58,88))
		var rotation: float = lid*TAU*2
		sprite("gear_large",Rect2(x-24,161,48,48),side*rotation)
		sprite("gear_small",Rect2(x-16,204,32,32),-side*rotation*1.5+deg_to_rad(11.25))
		sprite("connector",Rect2(x-5,241,10,18))
		sprite("connector",Rect2(x-6,382,12,53))
		for y in [248,430]:
			for yy in [y+20,y+112]: sprite("bracket",Rect2(x-17,yy,40,14),0,side>0)
			sprite("tube",Rect2(x-14,y,28,140))
			var tube_power: float = clampf((time-(.4 if y==248 else .48))/.1,0,1)
			draw_rect(Rect2(x-7,y+32,14,76),Color(.01,.07,.08,(1-tube_power)*.65))
			draw_rect(Rect2(x-7,y+32,14,76),Color(.27,.89,.73,tube_power*.17))
			for i in range(3):
				var py: float = y+32+fposmod(clock/1.6+i/3.0,1)*76
				var h: float = minf(8,y+108-py)
				draw_rect(Rect2(x-6,py,12,h),Color(.43,1,.83,tube_power*.5))
			if not closing:
				for i in range(7):
					var age: float = time-(.4 if y==248 else .48)-i*.006
					var life: float = .095+i*.007
					if age<0 or age>=life: continue
					var t: float = age/life
					var pos := Vector2(x+side*(5+(i*13%17)*t),y-t*(14+i*3)+t*t*10)
					draw_circle(pos,1+(i%3)*.45,Color(.65,1,.89,(1-t)*.8))
	var pulse: float = .92+.08*sin(clock/1.1) if time>=.7 else 1.0
	sprite("crystal",Rect2(532,100,56,66),0,false,1,.45+power*.75*pulse)
	sprite("holder",Rect2(509,82,102,102))
	for r in range(5): draw_circle(Vector2(560,134),20+r*5,Color(.26,.91,.72,power*.012))
