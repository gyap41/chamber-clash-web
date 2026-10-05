extends RefCounted
# Dedicated cutout art, enabled by default after the 2026-10-04 user adoption.
static var sheets: Dictionary = {}
static var bounds: Dictionary = {}
const TEXTURES := {
	"runner_sentry":preload("res://assets/first-workshop/enemies/remaining-machines/runner_sentry-v1.png"),
	"scatter_drone":preload("res://assets/first-workshop/enemies/remaining-machines/scatter_drone-v1.png"),
	"ram_sentry":preload("res://assets/first-workshop/enemies/remaining-machines/ram_sentry-v1.png"),
	"ring_sentry":preload("res://assets/first-workshop/enemies/remaining-machines/ring_sentry-v1.png")}
const REGIONS := {"runner_sentry":[[97,55,237,345],[509,55,236,344],[963,56,170,347],[121,452,164,335],[564,452,137,338],[973,452,164,338],[150,827,131,383],[563,828,126,379],[980,829,155,377]],"scatter_drone":[[61,38,343,402],[458,40,339,398],[881,37,318,401],[100,495,264,276],[492,494,270,270],[909,492,245,278],[153,804,122,382],[578,809,110,381],[995,807,120,384]],"ram_sentry":[[26,107,375,283],[443,90,372,298],[882,114,338,274],[33,486,366,291],[446,486,361,269],[944,486,228,292],[132,840,171,334],[541,840,168,334],[939,843,252,331]],"ring_sentry":[[20,134,398,255],[418,134,410,250],[873,132,343,285],[36,472,374,240],[450,472,358,234],[857,471,361,241],[91,760,246,399],[509,758,241,397],[913,759,277,394]]}
const IDS := ["runner_sentry","scatter_drone","ram_sentry","ring_sentry"]
const SIZES := {
	"runner_sentry":[Vector2(30,32),Vector2(11,21),Vector2(10,21)],
	"scatter_drone":[Vector2(40,34),Vector2(25,16),Vector2(12,24)],
	"ram_sentry":[Vector2(50,34),Vector2(45,25),Vector2(13,24)],
	"ring_sentry":[Vector2(50,28),Vector2(52,25),Vector2(13,25)]}

static func _static_init() -> void:
	for id in IDS: register_sheet(id,TEXTURES[id],[],REGIONS[id])

static func register_sheet(id: String, texture: Texture2D, rows: Array, measured: Array = []) -> void:
	sheets[id] = texture
	if measured.size() == 9:
		var exact: Array[Rect2] = []
		for rect in measured: exact.append(Rect2(rect[0],rect[1],rect[2],rect[3]))
		bounds[id] = exact
		return
	var image := texture.get_image()
	var regions: Array[Rect2] = []
	for row in range(3):
		for col in range(3):
			var cell := Rect2i(col*image.get_width()/3,int(rows[row]),image.get_width()/3,int(rows[row+1]-rows[row]))
			var used := image.get_region(cell).get_used_rect()
			regions.append(Rect2(used.position+cell.position,used.size))
	bounds[id] = regions

static func column(angle: float) -> int:
	var axis := Vector2.from_angle(angle)
	return 2 if absf(axis.x) > absf(axis.y) else (0 if axis.y >= 0 else 1)

static func factor(id: String, row: int) -> float:
	var largest := Vector2.ZERO
	for col in range(3): largest = largest.max(bounds[id][row*3+col].size)
	var desired: Vector2 = SIZES[id][row]
	return minf(desired.x/maxf(1,largest.x),desired.y/maxf(1,largest.y))

static func piece(canvas: Node2D, id: String, row: int, col: int, point: Vector2, mirror: bool, tint: Color, turn: float = 0.0) -> void:
	var source: Rect2 = bounds[id][row*3+col]
	var size: Vector2 = source.size*factor(id,row)
	canvas.draw_set_transform(point,turn,Vector2(-1 if mirror else 1,1))
	canvas.draw_texture_rect_region(sheets[id],Rect2(-size*.5,size),source,tint)
	canvas.draw_set_transform(Vector2.ZERO)

static func limb(canvas: Node2D, id: String, col: int, hip: Vector2, foot: Vector2, tint: Color, mirror: bool) -> void:
	var source: Rect2 = bounds[id][6+col]
	var delta := foot-hip
	var width: float = source.size.x*factor(id,2)
	canvas.draw_set_transform(hip,delta.angle()-PI/2,Vector2(-1 if mirror else 1,1))
	canvas.draw_texture_rect_region(sheets[id],Rect2(-width*.5,-2,width,delta.length()+3),source,tint)
	canvas.draw_set_transform(Vector2.ZERO)

static func pose(view: Dictionary) -> Dictionary:
	var phase: String = view.get("phase","grace")
	var dead: float = maxf(0,float(view.get("death_progress",-1)))
	var charge: float = clampf(1-float(view.get("remaining",0))/maxf(.01,float(view.get("windup",1))),0,1) if phase == "windup" else 0.0
	var recovery: float = clampf(float(view.get("remaining",0))/maxf(.01,float(view.get("recovery",1))),0,1) if phase == "recover" else 0.0
	var kick: float = clampf(1-(float(view.get("shot_interval",.5))-float(view.get("remaining",0)))/.16,0,1) if phase == "spit" and dead == 0 else 0.0
	return {"charge":charge,"recovery":recovery,"kick":kick,"death":dead,
		"open":charge if phase == "windup" else (1.0 if phase == "spit" else recovery)}

static func paint(canvas: Node2D, view: Dictionary) -> bool:
	var id: String = view.get("enemy_id","")
	if not sheets.has(id): return false
	var death: float = float(view.get("death_progress",-1))
	if not view.get("alive",true) and death < 0: return true
	var state := pose(view)
	var alpha := 1.0-smoothstep(.55,1,state.death)
	var angle: float = float(view.get("angle",0))
	var axis := Vector2.from_angle(angle)
	var col := column(angle)
	var mirror: bool = col == 2 and axis.x < 0
	# The generated patrol-lantern side view faces left; reverse its directional art.
	if id == "scatter_drone" and col == 2: mirror = not mirror
	var phase: String = view.get("phase","grace")
	var gait: float = float(view.get("gait",0))
	var motion: float = float(view.get("motion",0)) if death < 0 else 0.0
	var clock: float = float(view.get("visual_time",0))
	var hit: float = float(view.get("hit",0)) if death < 0 else 0.0
	var tint := Color(1+hit*.6,1+hit*.5,1+hit*.3,alpha)
	var body := Vector2(sin(hit*20)*hit*2,-27+state.death*24)
	canvas.draw_set_transform(Vector2.ZERO,0,Vector2(1,.32))
	canvas.draw_circle(Vector2.ZERO,18 if id == "runner_sentry" else 25,Color(0,0,0,.28*alpha))
	canvas.draw_set_transform(Vector2.ZERO)
	if id == "scatter_drone":
		body.y += sin(clock*3)*2 if death < 0 else 0.0
		for side in [-1,1]:
			piece(canvas,id,2,col,body+Vector2(side*(13+state.open*3+state.death*15),4),side < 0,tint,side*(state.open*.2+state.death*.8))
		piece(canvas,id,0,col,body,mirror,tint,state.death*.4)
		var muzzle: Vector2 = body+axis*Vector2(15,8)+Vector2(0,11)-axis*state.kick*4+Vector2(0,state.death*15)
		piece(canvas,id,1,col,muzzle,mirror,tint,state.death*-.6)
	else:
		var count: int = 2 if id == "runner_sentry" else (3 if id == "ring_sentry" else 4)
		for n in range(count):
			var side: float = -1.0 if n%2 == 0 else 1.0
			var foot := Vector2(side*(8 if count == 2 else 20),2+(n/2)*4)
			if count == 3: foot = Vector2(cos(angle+n*TAU/3)*23,sin(angle+n*TAU/3)*9+3)
			var hip := Vector2(foot.x*.65,-16+foot.y*.25+state.death*14)
			var cycle := fposmod(gait/TAU+float(n)/count,1)
			var stride: float = 24.7*(.5-cycle/.65) if cycle < .65 else 24.7*(-.5+(cycle-.65)/.35)
			foot += axis*stride*motion
			if cycle >= .65: foot.y -= sin((cycle-.65)/.35*PI)*5*motion
			foot.x += side*state.death*15
			limb(canvas,id,col,hip,foot,tint,side < 0)
		body += axis*Vector2(1,.4)*(-state.charge*3+state.recovery*2)
		piece(canvas,id,0,col,body,mirror,tint,state.death*.25)
		if id == "runner_sentry":
			for side in [-1,1]:
				var swing: float = sin(gait+PI*(1 if side < 0 else 0))*.35*motion
				var strike: float = -state.charge*.8+state.recovery*.55
				piece(canvas,id,1,col,body+Vector2(side*(10+state.death*14),6-state.charge*7),side < 0,tint,side*(swing+strike+state.death*.9))
		elif id == "ram_sentry":
			var extension: float = 7.0 if phase == "dash" and death < 0 else -state.charge*5+state.recovery*3
			piece(canvas,id,1,col,body+axis*Vector2(22,10)+axis*extension+Vector2(0,7+state.death*9),mirror,tint,state.death*-.3)
		else:
			piece(canvas,id,1,col,body+Vector2(0,-9-state.open*6+state.kick*4+state.death*12),mirror,tint,state.death*-.4)
			if death < 0 and state.open > 0:
				canvas.draw_arc(Vector2.ZERO,31,angle-PI/4,angle+PI/4,18,Color(.45,.85,.72,state.open*.45),1.5,true)
	if death < 0 and state.kick > 0:
		for n in range(5 if id == "scatter_drone" else 11):
			var heading: float = angle+(n-2)*.28 if id == "scatter_drone" else angle+(n+3)*TAU/16
			var ray := Vector2.from_angle(heading)
			var origin: Vector2 = body+ray*Vector2(23,13)+Vector2(0,4)
			canvas.draw_line(origin,origin+ray*(5+8*state.kick),Color(1,.84,.45,state.kick),2,true)
	if death < 0 and phase == "recover" and id != "runner_sentry":
		for n in range(3):
			var t := fposmod(clock*2+n/3.0,1)
			canvas.draw_circle(body+Vector2((n-1)*8,-13-t*14),2+t*3,Color(.75,.8,.74,(1-t)*.18*state.recovery))
	canvas.draw_set_transform(Vector2.ZERO)
	return true
