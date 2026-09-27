extends RefCounted
# Dedicated direction/pose frames. Original PNGs are never modified.
const QUILLBACK = preload("res://assets/first-workshop/enemies/quillback-sheet-v1.png")
const SENTRY = preload("res://assets/first-workshop/enemies/sentry-sheet-v2.png")
# v3 (2026-09-26): style-unified redraw built by tools/build_lizard_v3_atlas.gd; v2 stays on disk for rollback.
const LIZARD = preload("res://assets/first-workshop/enemies/lizard-sheet-v3.png")
# v3 is an even grid: 4 columns (front, back, right, left) x 8 rows, feet on one ground line per cell.
const LIZARD_CELL := Vector2(344,256)
const LIZARD_GROUND := 230.0
# White silhouette of the same atlas for the hit flash (the body is too bright to brighten by modulate).
const LIZARD_FLASH = preload("res://assets/first-workshop/enemies/lizard-sheet-v3-flash.png")
# Front/back views show the long body end-on, so they are drawn larger to keep the apparent size close to the side view.
const LIZARD_SCALE_SIDE := .24
const LIZARD_SCALE_END := .30
# Throat-pouch centre per column (front, back, right, left) in atlas pixels from the ground anchor.
# The back view hides the pouch; during the attack its glow sits where the pouch bulges out on both
# sides of the neck. It stays off while walking there (outside the body it read as brown "ears").
# Ground shadow per enemy and column (front, back, right, left): centre x, centre y, half width, half height
# in screen pixels. Sized to the drawn body (measured from the sheets) and placed on the feet line so the
# enemy reads as standing on the floor.
const SHADOWS := {
	"sentry":[Vector4(-1,-3,19,6),Vector4(1,-3,19,6),Vector4(3,-3,15,5),Vector4(-4,-3,15,5)],
	"quillback":[Vector4(3,-4,18,7),Vector4(0,-4,19,7),Vector4(1,-5,25,7),Vector4(-1,-5,25,7)],
	"lizard":[Vector4(0,-5,24,8),Vector4(0,-5,24,8),Vector4(0,-3,32,6),Vector4(0,-3,32,6)],
}
const LIZARD_POUCH := [[Vector2(0,-22)],[Vector2(-70,-105),Vector2(70,-105)],[Vector2(60,-46)],[Vector2(-60,-46)]]
const SENTRY_Y := [0,235,435,635,815,1045,1280,1500,1774]
const SENTRY_GROUND := [214,406,599,795,1033,1230,1455,1665]

static func frame(view: Dictionary, lizard: bool) -> Dictionary:
	var direction := Vector2.from_angle(float(view.angle))
	var col := (2 if direction.x >= 0 else 3) if absf(direction.x) > absf(direction.y) else (0 if direction.y >= 0 else 1)
	var row := 6
	if view.get("death_progress",-1.0) >= 0: row = 7
	elif view.phase == "windup": row = 4
	elif lizard and view.phase == "spit": row = 5
	elif not lizard and view.phase == "recover" and float(view.recovery)-float(view.remaining) < .2: row = 5
	elif view.phase == "chase" and float(view.get("motion",0)) > .1: row = int(fposmod(float(view.get("gait",0)),TAU)/TAU*4)%4
	if view.get("enemy_id","") == "quillback":
		var size := QUILLBACK.get_size()
		var xs := [0.0,.25,.5,.75,1.0]
		var ys := [0.0,.13,.245,.365,.48,.60,.72,.845,1.0]
		var ground := [.115,.235,.35,.47,.585,.71,.83,.955]
		var origin := Vector2(xs[col]*size.x,ys[row]*size.y)
		return {"region":Rect2(origin,Vector2(.25*size.x,(ys[row+1]-ys[row])*size.y)),
			"anchor":Vector2((xs[col]+.125)*size.x,ground[row]*size.y)-origin,
			"scale":.34,"row":row,"column":col,"mirror":false}
	if lizard:
		return {"region":Rect2(Vector2(col,row)*LIZARD_CELL,LIZARD_CELL),
			"anchor":Vector2(LIZARD_CELL.x*.5,LIZARD_GROUND),
			"scale":LIZARD_SCALE_END if col < 2 else LIZARD_SCALE_SIDE,"row":row,"column":col,"mirror":false}
	var ys: Array = SENTRY_Y
	var xs := [0,225,445,665,887]
	var region := Rect2(xs[col],ys[row],xs[col+1]-xs[col],ys[row+1]-ys[row])
	if row == 7 and col == 2: region.size.x = 205 # Exclude the neighboring left-pose edge.
	var ax: float = [132,342,547,760][col]
	var ay: float = SENTRY_GROUND[row]
	if row == 5:
		ax = [128,339,513,791][col]
		ay = [1217,1245,1235,1235][col]
	return {"region":region,"anchor":Vector2(ax,ay)-region.position,
		"scale":.36,"row":row,"column":col,"mirror":false}

static func paint(canvas: Node2D, view: Dictionary, lizard: bool) -> void:
	var death := float(view.get("death_progress",-1))
	if not view.alive and death < 0: return
	var selected := frame(view,lizard)
	var moving := float(view.get("motion",0))
	var gait := float(view.get("gait",0))
	var clock := float(view.get("visual_time",0))
	# Feet stay on the floor: the walk frames carry the step, so there is no whole-sprite lift or idle bob.
	var offset := Vector2.ZERO
	var angle := 0.0
	var fire_lizard: bool = lizard and view.get("enemy_id","") != "quillback"
	var kind := "quillback" if view.get("enemy_id","") == "quillback" else ("lizard" if lizard else "sentry")
	# The lizard's front/back views show little leg travel, so walking adds a side sway and a tilt about the feet.
	if fire_lizard and selected.column < 2 and moving > .1:
		offset.x = sin(gait)*1.5*moving
		angle = sin(gait)*.07*moving
	var color := Color.WHITE
	var direction := Vector2.from_angle(float(view.angle))
	# Lean/recoil moves along the floor; its vertical part is damped so front views do not lift.
	var lean_axis := Vector2(1,.3)
	if view.phase == "windup":
		offset -= direction*smoothstep(0,1,1.0-float(view.remaining)/float(view.windup))*3*lean_axis
	elif selected.row == 5:
		var kick := clampf(float(view.remaining)/.22,0,1) if lizard else maxf(0,1-(float(view.recovery)-float(view.remaining))/.2)
		offset += direction*kick*(-4 if lizard else 5)*lean_axis
	var hit := float(view.get("hit",0))
	if hit > 0 and death < 0:
		offset.x += sin(hit*TAU*2)*2*hit
		if not fire_lizard: color = Color(1+.7*hit,1+.5*hit,1+.5*hit)
	if death >= 0:
		# Collapse in place; no hop off the floor.
		offset = Vector2.ZERO
		color = Color(.85,.85,.85,1-smoothstep(.55,1,death))
		angle = sin(death*PI*2)*.08*(1-death)
	var shadow: Vector4 = SHADOWS[kind][selected.column]
	canvas.draw_set_transform(Vector2(shadow.x,shadow.y),0,Vector2(1,shadow.w/shadow.z))
	canvas.draw_circle(Vector2.ZERO,shadow.z,Color(0,0,0,.3*color.a))
	# Darker contact core under the body.
	canvas.draw_circle(Vector2.ZERO,shadow.z*.62,Color(0,0,0,.22*color.a))
	canvas.draw_set_transform(offset,angle)
	var region: Rect2 = selected.region
	var rect := Rect2(-Vector2(selected.anchor)*float(selected.scale),region.size*float(selected.scale))
	if fire_lizard and death < 0: paint_pouch_glow(canvas,view,selected,clock)
	canvas.draw_texture_rect_region(QUILLBACK if view.get("enemy_id","") == "quillback" else (LIZARD if lizard else SENTRY),
		rect,region,color)
	if fire_lizard and hit > 0 and death < 0:
		canvas.draw_texture_rect_region(LIZARD_FLASH,rect,region,Color(1,1,1,.75*hit))
	canvas.draw_set_transform(Vector2.ZERO)
	if death >= 0: return
	if not lizard and selected.row == 5:
		canvas.draw_arc(Vector2.ZERO,float(view.reach)-10,float(view.angle)-.45,float(view.angle)+.45,12,Color(1,.85,.55,.5),2,true)
	canvas.draw_line(Vector2(-14,22),Vector2(14,22),Color("3b2924"),3)
	canvas.draw_line(Vector2(-14,22),Vector2(-14+28*float(view.hp_ratio),22),Color("e69258"),3)

# Ember glow behind the fire-pouch lizard's throat: faint while idle/walking, swelling through the windup,
# fading after the spit. Drawn behind the sprite so it reads as light leaking around the body.
static func paint_pouch_glow(canvas: Node2D, view: Dictionary, selected: Dictionary, clock: float) -> void:
	var strength := .35+.08*sin(clock*4.0)
	var radius := 9.0
	if selected.column == 1 and view.phase != "windup" and selected.row != 5: return
	if view.phase == "windup":
		var t := smoothstep(0,1,1.0-float(view.remaining)/maxf(float(view.windup),.01))
		strength = lerpf(.35,.95,t)
		radius = lerpf(8.0,15.0,t)
	elif selected.row == 5:
		strength = .9*clampf(float(view.remaining)/.22,0,1)
		radius = 12.0
	for point in LIZARD_POUCH[selected.column]:
		var centre: Vector2 = point*float(selected.scale)
		canvas.draw_circle(centre,radius,Color(1,.5,.12,.28*strength))
		canvas.draw_circle(centre,radius*.55,Color(1,.72,.3,.5*strength))
