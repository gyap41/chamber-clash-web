extends RefCounted
# Directional cutout rigs. Texture dimensions and combat collision remain independent.
const RAM = preload("res://assets/first-workshop/enemies/elite-machines/ash-ram-parts-v1.png")
const RING = preload("res://assets/first-workshop/enemies/elite-machines/triple-ring-parts-v1.png")
static var regions := {}

static func column(angle: float) -> int:
	var direction := Vector2.from_angle(angle)
	return 2 if absf(direction.x) > absf(direction.y) else (0 if direction.y >= 0 else 1)

static func region(ram: bool, row: int, col: int) -> Rect2:
	var key := "%s/%d/%d" % [ram,row,col]
	if not regions.has(key):
		var texture: Texture2D = RAM if ram else RING
		var size := texture.get_size()
		# Measured empty gutters, not per-frame rescaling. Original sheets are untouched.
		var ys: Array = [0.0,.355,.68,1.0] if ram else [0.0,.335,.635,1.0]
		var cell := Rect2i(int(col*size.x/3),int(ys[row]*size.y),int(size.x/3),int((ys[row+1]-ys[row])*size.y))
		var used := texture.get_image().get_region(cell).get_used_rect()
		regions[key] = Rect2(used.position+cell.position,used.size)
	return regions[key]

static func piece(canvas: Node2D, ram: bool, row: int, col: int, pos: Vector2, factor: float, mirror: bool, tint: Color, rotation: float = 0.0) -> void:
	var source := region(ram,row,col)
	canvas.draw_set_transform(pos,rotation,Vector2(-1 if mirror else 1,1))
	canvas.draw_texture_rect_region(RAM if ram else RING,Rect2(-source.size*factor*.5,source.size*factor),source,tint)
	canvas.draw_set_transform(Vector2.ZERO)

static func leg(canvas: Node2D, col: int, hip: Vector2, foot: Vector2, mirror: bool, tint: Color) -> void:
	var source := region(false,2,col)
	var delta := foot-hip
	canvas.draw_set_transform(hip,delta.angle()-PI/2,Vector2(-1 if mirror else 1,1))
	# The top hinge stays inside the hull; stride changes the joint angle and extension.
	canvas.draw_texture_rect_region(RING,Rect2(-source.size.x*.065*.5,0,source.size.x*.065,delta.length()),source,tint)
	canvas.draw_set_transform(Vector2.ZERO)

static func pose(view: Dictionary) -> Dictionary:
	var phase: String = view.get("phase","grace")
	var charge := clampf(1-float(view.get("remaining",0))/maxf(.01,float(view.get("windup",1))),0,1) if phase == "windup" else 0.0
	var recover := clampf(float(view.get("remaining",0))/maxf(.01,float(view.get("recovery",1))),0,1) if phase == "recover" else 0.0
	var kick := 0.0
	if phase == "spit": kick = clampf(1.0-(float(view.get("shot_interval",.5))-float(view.get("remaining",0)))/.16,0,1)
	return {"charge":charge,"recover":recover,"kick":kick,"open":charge if phase == "windup" else (1.0 if phase == "spit" else recover)}

static func paint(canvas: Node2D, view: Dictionary) -> void:
	var death := float(view.get("death_progress",-1))
	if not view.get("alive",true) and death < 0: return
	var ram: bool = view.get("enemy_id","") == "ash_ram"
	var angle := float(view.get("angle",0))
	var direction := Vector2.from_angle(angle)
	var col := column(angle)
	var mirror := col == 2 and direction.x < 0
	var phase: String = view.get("phase","grace")
	var gait := float(view.get("gait",0))
	var motion := float(view.get("motion",0)) if death < 0 else 0.0
	var clock := float(view.get("visual_time",0))
	var state := pose(view)
	var collapse := maxf(0,death)
	var alpha := 1.0-smoothstep(.55,1.0,collapse)
	var hit := float(view.get("hit",0)) if death < 0 else 0.0
	var tint := Color(1+hit*.7,1+hit*.4,1+hit*.2,alpha)
	canvas.draw_set_transform(Vector2.ZERO,0,Vector2(1,.32))
	canvas.draw_circle(Vector2.ZERO,29 if ram else 31,Color(0,0,0,.3*alpha))
	canvas.draw_set_transform(Vector2.ZERO)
	var body := Vector2(sin(hit*24)*hit*2,-23+collapse*19)
	if ram:
		body += direction*Vector2(1,.4)*(-state.charge*3+state.recover*2)
		for side in [-1,1]:
			var pod := Vector2(side*18,0) if col < 2 else Vector2(side*6,side*7-2)
			pod.x += side*collapse*10
			piece(canvas,true,2,col,pod,.095,mirror,tint,side*collapse*.3)
			# Belt links circulate only with actual displacement, including a dash.
			for n in range(4):
				var x := fposmod(n*6+gait*3*motion,24)-12
				canvas.draw_line(pod+Vector2(x,5),pod+Vector2(x+2,7),Color(.72,.61,.4,.65*alpha),1.2,true)
		var plate: Vector2 = body+Vector2(direction.x*22,direction.y*13+5)+direction*(7 if phase == "dash" else -state.charge*6+state.recover*5)
		plate += direction*collapse*16
		if col == 1: piece(canvas,true,1,col,plate,.112,mirror,tint,collapse*.3)
		piece(canvas,true,0,col,body,.135,mirror,tint,collapse*-.18)
		if col != 1: piece(canvas,true,1,col,plate,.112,mirror,tint,collapse*.3)
		if death < 0 and phase == "windup":
			var across := direction.orthogonal()
			# Short brackets identify the fixed attack direction without painting a false damage area.
			for side in [-1,1]:
				var start: Vector2 = direction*28+across*side*16
				canvas.draw_line(start,start+direction*(8+state.charge*13),Color(1,.66,.23,.25+.5*state.charge),2,true)
		if death < 0 and phase == "dash":
			var flash := clampf((float(view.get("dash_left",0))-270)/40,0,1)
			for n in range(5):
				var axis := Vector2.from_angle(angle+PI+(n-2)*.22)
				canvas.draw_line(axis*18,axis*(25+(1-flash)*16),Color(1,.8,.42,flash*.8),2,true)
		if death < 0 and phase in ["dash","recover"]:
			for n in range(3):
				var t := fposmod(clock*3+n/3.0,1)
				canvas.draw_circle(body-direction*(16+t*16)+Vector2(0,-t*10),2+t*3,Color(.7,.65,.5,(1-t)*.25))
	else:
		var feet: Array[Vector2] = []
		for n in range(3):
			var heading := angle+n*TAU/3+PI
			var foot := Vector2(cos(heading)*23,sin(heading)*10+2)
			var hip := Vector2(foot.x*.5,-14+foot.y*.3+collapse*12)
			var cycle := fposmod(gait/TAU+n/3.0,1)
			var stride := 24.7*(.5-cycle/.65) if cycle < .65 else 24.7*(-.5+(cycle-.65)/.35)
			foot += direction*stride*motion
			if cycle >= .65: foot.y -= sin((cycle-.65)/.35*PI)*5*motion
			foot += Vector2(cos(heading)*collapse*15,collapse*4)
			feet.append(foot)
			leg(canvas,col,hip,foot,mirror,tint)
		body.y += sin(gait*3)*motion*.7
		piece(canvas,false,0,col,body,.135,mirror,tint,collapse*.2)
		var turret := body+Vector2(0,-10-state.open*7+state.kick*4+collapse*10)
		for side in [-1,1]: canvas.draw_line(body+Vector2(side*8,-3),turret+Vector2(side*8,5),Color(.65,.49,.24,alpha),3,true)
		piece(canvas,false,1,col,turret,.14,mirror,tint,-collapse*.35)
		if death < 0 and state.open > 0:
			# Closed ivory sector in the art corresponds to the safe firing direction.
			canvas.draw_arc(Vector2.ZERO,33,angle-PI/4,angle+PI/4,16,Color(.5,.85,.7,.45*state.open),1.5,true)
			for n in range(3,14):
				var axis := Vector2.from_angle(angle+n*TAU/16)
				var muzzle: Vector2 = turret+axis*Vector2(23,15)
				var fired: bool = n in view.get("firing_muzzles",[])
				var kick: float = state.kick if fired else 0.0
				canvas.draw_circle(muzzle,1.5+kick*2,Color(1,.68,.25,(.25+.65*kick)*state.open))
				if kick > 0:
					canvas.draw_line(muzzle,muzzle+axis*(7+kick*8),Color(1,.92,.65,kick),2.2,true)
					canvas.draw_circle(muzzle+axis*(10+(1-kick)*12),2+(1-kick)*3,Color(.74,.8,.73,kick*.24))
		if death < 0 and phase == "recover":
			for n in range(3):
				var t := fposmod(clock*1.8+n/3.0,1)
				canvas.draw_circle(turret+Vector2((n-1)*9,-t*16),2+t*3,Color(.72,.8,.73,(1-t)*.23*state.recover))
	if death < 0:
		canvas.draw_line(Vector2(-15,15),Vector2(15,15),Color("342c24"),3)
		canvas.draw_line(Vector2(-15,15),Vector2(-15+30*float(view.get("hp_ratio",1)),15),Color("e0aa59"),3)
