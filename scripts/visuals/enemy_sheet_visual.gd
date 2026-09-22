extends RefCounted
# Dedicated direction/pose frames. Original PNGs are never modified.
const SENTRY = preload("res://assets/first-workshop/enemies/sentry-sheet-v2.png")
const LIZARD = preload("res://assets/first-workshop/enemies/lizard-sheet-v2.png")
const SENTRY_Y := [0,235,435,635,815,1045,1280,1500,1774]
const LIZARD_Y := [0,240,440,645,855,1065,1285,1505,1774]
const SENTRY_GROUND := [214,406,599,795,1033,1230,1455,1665]
const LIZARD_GROUND := [200,400,604,807,1017,1230,1440,1640]

static func frame(view: Dictionary, lizard: bool) -> Dictionary:
	var direction := Vector2.from_angle(float(view.angle))
	var col := (2 if direction.x >= 0 else 3) if absf(direction.x) > absf(direction.y) else (0 if direction.y >= 0 else 1)
	var row := 6
	if view.get("death_progress",-1.0) >= 0: row = 7
	elif view.phase == "windup": row = 4
	elif lizard and view.phase == "spit": row = 5
	elif not lizard and view.phase == "recover" and float(view.recovery)-float(view.remaining) < .2: row = 5
	elif view.phase == "chase" and float(view.get("motion",0)) > .1: row = int(fposmod(float(view.get("gait",0)),TAU)/TAU*4)%4
	var ys: Array = LIZARD_Y if lizard else SENTRY_Y
	var xs := [0,215,410,650,887] if lizard else [0,225,445,665,887]
	var region := Rect2(xs[col],ys[row],xs[col+1]-xs[col],ys[row+1]-ys[row])
	if not lizard and row == 7 and col == 2: region.size.x = 205 # Exclude the neighboring left-pose edge.
	var ax: float = ([102,313,530,775] if lizard else [132,342,547,760])[col]
	var ay: float = (LIZARD_GROUND if lizard else SENTRY_GROUND)[row]
	if not lizard and row == 5:
		ax = [128,339,513,791][col]
		ay = [1217,1245,1235,1235][col]
	return {"region":region,"anchor":Vector2(ax,ay)-region.position,
		"scale":.32 if lizard else .36,"row":row,"column":col,"mirror":false}

static func paint(canvas: Node2D, view: Dictionary, lizard: bool) -> void:
	var death := float(view.get("death_progress",-1))
	if not view.alive and death < 0: return
	var selected := frame(view,lizard)
	var moving := float(view.get("motion",0))
	var gait := float(view.get("gait",0))
	var clock := float(view.get("visual_time",0))
	var offset := Vector2(0,-absf(sin(gait))*1.4*moving)
	var angle := 0.0
	var color := Color.WHITE
	var direction := Vector2.from_angle(float(view.angle))
	if view.phase == "windup":
		offset -= direction*smoothstep(0,1,1.0-float(view.remaining)/float(view.windup))*3
	elif selected.row == 5:
		var kick := clampf(float(view.remaining)/.22,0,1) if lizard else maxf(0,1-(float(view.recovery)-float(view.remaining))/.2)
		offset += direction*kick*(-4 if lizard else 5)
	if moving < .1: offset.y -= sin(clock*3)*.5
	var hit := float(view.get("hit",0))
	if hit > 0 and death < 0:
		offset.x += sin(hit*TAU*2)*2*hit
		color = Color(1+.7*hit,1+.5*hit,1+.5*hit)
	if death >= 0:
		offset = Vector2(0,-sin(clampf(death/.3,0,1)*PI)*5)
		color = Color(.85,.85,.85,1-smoothstep(.55,1,death))
		angle = sin(death*PI*2)*.08*(1-death)
	canvas.draw_set_transform(Vector2(0,3),0,Vector2(1,.4))
	canvas.draw_circle(Vector2.ZERO,21,Color(0,0,0,.35*color.a))
	canvas.draw_set_transform(offset,angle)
	var region: Rect2 = selected.region
	canvas.draw_texture_rect_region(LIZARD if lizard else SENTRY,
		Rect2(-Vector2(selected.anchor)*float(selected.scale),region.size*float(selected.scale)),region,color)
	canvas.draw_set_transform(Vector2.ZERO)
	if death >= 0: return
	if not lizard and selected.row == 5:
		canvas.draw_arc(Vector2.ZERO,float(view.reach)-10,float(view.angle)-.45,float(view.angle)+.45,12,Color(1,.85,.55,.5),2,true)
	canvas.draw_line(Vector2(-14,22),Vector2(14,22),Color("3b2924"),3)
	canvas.draw_line(Vector2(-14,22),Vector2(-14+28*float(view.hp_ratio),22),Color("e69258"),3)
