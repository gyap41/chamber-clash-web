extends RefCounted
const BODY = preload("res://assets/sprites/boss/foundry-spinner/body.png")
const PARTS = preload("res://assets/sprites/boss/foundry-spinner/parts.png")
const FX = preload("res://assets/sprites/boss/foundry-spinner/effects.png")

static func paint(c: Node2D, v: Dictionary) -> void:
	var death: float = v.get("death_progress",-1.0)
	var alpha := 1.0-clampf(death,0,1) if death >= 0 else 1.0
	var angle: float = v.angle
	var t: float = v.get("spin_time",0)
	var lift: float = v.get("lift",0)
	var opening: float = v.get("opening",0)
	var direction := Vector2.from_angle(angle)
	var column := 0 if direction.y > .6 else (2 if direction.y < -.6 else (1 if direction.x > 0 else 3))
	# Ground projection stays fixed; do not rotate the whole overhead sprite.
	c.draw_set_transform(Vector2(0,5),0,Vector2(1,.38))
	c.draw_circle(Vector2.ZERO,68-lift*.18,Color(0,0,0,.38*alpha))
	c.draw_set_transform(Vector2.ZERO)
	paint_muzzles(c,v,true)
	for particle in v.get("particles",[]):
		var point: Vector2 = particle.pos-v.position
		var fade: float = particle.life/particle.total
		if particle.smoke:
			c.draw_circle(point,particle.size*(2-fade),Color(.38,.32,.26,fade*.18*alpha))
		else:
			c.draw_line(point,point-particle.velocity*.035,Color(1,.64,.2,fade*alpha),1.8,true)
	if death >= 0:
		c.draw_texture_rect_region(PARTS,Rect2(-90,-116+death*15,180,158),Rect2(1086,724,362,362),Color(1,1,1,alpha))
	else:
		var drive: float = v.get("drive",0)
		var tilt := sin(t*14)*.035*drive
		var recoil: float = v.get("recoil",0)
		var settle := sin(t*9)*2.0 if v.phase == "recover" else sin(t*4)*.8
		var compression := 1.0-.025*(sin(t*7)*.5+.5) if v.phase == "windup" else 1.0
		var shake := Vector2.ZERO
		if v.phase == "grace":
			var activation: float = v.get("startup",1.0)
			shake = Vector2(sin(t*40),0)*sin(activation*PI)*2
		if v.phase == "transition":
			shake = Vector2(sin(t*80)*3,cos(t*63)*2)
			tilt = sin(t*45)*.025
		c.draw_set_transform(Vector2(0,-lift+settle)+direction*(lift*(0.0 if v.move_name == "shockwave" else .6)-recoil*5-drive*3)+shake,tilt,Vector2(1,compression))
		var rect := Rect2(-96,-218,192,256)
		var tint := Color(1.25,1.18,1.05) if v.get("hit",0) > .6 else Color.WHITE
		if v.phase == "grace": tint = Color(.38,.35,.3).lerp(Color.WHITE,smoothstep(.05,.65,float(v.get("startup",1.0))))
		# Registered cells share one scale. Row anchors compensate for sheet margins.
		if opening <= 0:
			c.draw_texture_rect_region(BODY,rect,Rect2(column*384,0,384,512),tint)
		elif opening >= 1:
			c.draw_texture_rect_region(BODY,Rect2(-96,-197,192,256),Rect2(column*384,512,384,512),tint)
		else:
			# Direction-specific keyed poses; pressure flare conceals the latch release.
			# Never cut the whole sprite into strips: that splits the chimney/base too.
			var row := 0 if opening < .5 else 1
			var top := -218.0 if row == 0 else -197.0
			c.draw_texture_rect_region(BODY,Rect2(-96,top,192,256),Rect2(column*384,row*512,384,512),tint)
			var glow := pow(sin(opening*PI),8)
			c.draw_circle(Vector2(0,-78),65,Color(1,.58,.18,glow*.22))
			c.draw_circle(Vector2(0,-78),40,Color(1,.91,.6,glow*.48))
			for vent in [-1,1]:
				for puff in range(5):
					var travel := fposmod(opening*1.8+puff*.16,1.0)
					c.draw_circle(Vector2(vent*(45+travel*45),-65-travel*28),6+travel*13,Color(.65,.59,.47,(1-travel)*sin(opening*PI)*.3))
		# Orbiting hot vents convey ring movement without rotating projected geometry.
		for index in range(10):
			var a := t*3.5+index*TAU/10
			if sin(a) < 0: continue
			var point := Vector2(cos(a)*74,sin(a)*20-7)
			c.draw_circle(point,2.0,Color(1,.55,.12,.55+.3*opening))
		c.draw_set_transform(Vector2.ZERO)
	var impact: float = v.get("impact_age",10)
	if impact < .42:
		var frame := mini(3,int(impact/.105))
		if v.get("impact_kind","") == "slam":
			c.draw_arc(Vector2.ZERO,180,angle-.65,angle+.65,32,Color(1,.65,.2,(1-impact/.42)*.7),4,true)
		c.draw_texture_rect_region(FX,Rect2(-115,-48,230,100),Rect2(frame*384,768,384,256),Color(1,1,1,1-impact/.42))
	if death < 0 and v.get("cannon_charge",0.0) > 0:
		var charge: float = v.cannon_charge
		var port := preload("res://scripts/visuals/boss_cannon_art.gd").muzzle_point(angle,true)
		c.draw_circle(port,10+charge*10,Color(1,.45,.12,.18*charge))
		c.draw_circle(port,3+charge*5,Color(1,.86,.45,.8*charge))
	paint_muzzles(c,v,false)
	if death < 0:
		for wave in v.get("waves",[]):
			var center: Vector2 = wave.origin-v.position
			paint_wave(c,center,float(wave.radius),t)

# Visual-only trailing turbulence. The bright leading edge stays on the hit radius.
static func paint_muzzles(c: Node2D, v: Dictionary, behind: bool) -> void:
	var flash: float = v.get("flash_age",10)
	if flash >= (.24 if v.move_name == "cannon" else .18) or v.get("death_progress",-1.0) >= 0: return
	if v.move_name == "machinegun":
		if behind or flash >= .10: return
		c.draw_set_transform(v.get("muzzle",Vector2.ZERO),v.get("muzzle_angle",0))
		c.draw_texture_rect_region(FX,Rect2(-12,-15,48,30),Rect2(mini(3,int(flash/.025))*384,256,384,256),Color(1,1,1,1-flash/.10))
		c.draw_set_transform(Vector2.ZERO)
		return
	var art = preload("res://scripts/visuals/boss_cannon_art.gd")
	for angle in v.get("muzzle_angles",[]):
		if (sin(angle) < -.2) != behind: continue
		art.muzzle(c,art.muzzle_point(angle,v.move_name == "cannon"),angle,v.move_name == "cannon",flash)

static func paint_wave(c: Node2D, center: Vector2, radius: float, time: float) -> void:
	var strength := clampf(radius/45.0,0,1)
	var segments := clampi(int(TAU*radius/10),64,512)
	var hot := PackedVector2Array()
	var wake := PackedVector2Array()
	for i in range(segments+1):
		var a := TAU*i/segments
		var ripple := sin(a*31-time*9)*3+sin(a*57+time*13)*2
		var axis := Vector2.from_angle(a)
		hot.append(center+axis*(radius+ripple*.28))
		wake.append(center+axis*maxf(0,radius-10+ripple))
	c.draw_polyline(wake,Color(1,.24,.035,.09*strength),32,true)
	c.draw_polyline(wake,Color(1,.43,.08,.2*strength),15,true)
	c.draw_polyline(hot,Color(1,.64,.2,.65*strength),8,true)
	c.draw_polyline(hot,Color(1,.93,.66,.95*strength),2.3,true)
	var count := clampi(int(TAU*radius/65),12,96)
	var screen := c.get_viewport_rect().grow(80)
	var transform := c.get_global_transform_with_canvas()
	for i in range(count):
		var a := TAU*i/count
		var axis := Vector2.from_angle(a)
		var cycle := fposmod(time*2.2+i*.618,1.0)
		var point := center+axis*maxf(0,radius-8-cycle*32)
		if not screen.has_point(transform*point): continue
		var fade := sin(cycle*PI)*strength
		# Small dust frames add granular stone texture behind, never filling the ring.
		if i%2 == 0:
			c.draw_set_transform(point,a-PI/2)
			var frame := mini(3,int(cycle*4))
			c.draw_texture_rect_region(FX,Rect2(-25,-14,50,28),Rect2(frame*384,768,384,256),Color(1,.8,.57,.32*fade))
			c.draw_set_transform(Vector2.ZERO)
		var spark := center+axis*(radius-3-cycle*20)+axis.orthogonal()*sin(i*7.1)*7
		c.draw_line(spark,spark-axis*(4+cycle*10),Color(1,.75,.3,.8*fade),1.6,true)
		if i%3 == 0:
			c.draw_circle(point+Vector2(0,-cycle*9),1.4+cycle,Color(.4,.28,.16,.6*fade))

# Bounded procedural bursts reuse the generated dust and armor atlas.
# No physics bodies, damage, or timers survive the presentation node.
static func paint_destruction(c: Node2D, v: Dictionary, age: float) -> void:
	var view := v.duplicate()
	view.particles = []
	view.waves = []
	view.flash_age = 10.0
	view.impact_age = 10.0
	if age < 1.4:
		view.death_progress = -1.0
		view.phase = "recover"
		view.lift = 0.0
		view.drive = 0.0
		view.recoil = 0.0
		view.spin_time = float(v.get("spin_time",0))+minf(age,.2)
		paint(c,view)
	else:
		view.death_progress = clampf((age-2.8)/1.7,0,1)
		paint(c,view)
	for burst in range(5):
		var start := [0.0,.22,.8,1.1,1.4][burst] as float
		var time := age-start
		var duration := .45 if burst < 4 else 1.4
		if time < 0 or time > duration: continue
		var progress := time/duration
		var center := Vector2(-24,-95) if burst == 0 else Vector2(28,-55) if burst == 1 else Vector2(0,-60)
		var size := 32.0 if burst < 4 else 170.0
		c.draw_set_transform(center,0,Vector2.ONE*(1.5 if burst == 4 else .8))
		preload("res://scripts/visuals/boss_cannon_art.gd").impact(c,progress*.64,burst == 4)
		c.draw_set_transform(Vector2.ZERO)
		for layer in range(3):
			c.draw_circle(center,size*(.2+progress)*(1-layer*.22),Color(1,.27+layer*.22,.06+layer*.15,(1-progress)*(.12+layer*.16)))
		for i in range(14):
			var axis := Vector2.from_angle(i*2.399963+burst)
			var point := center+axis*size*progress
			c.draw_line(point,point-axis*(5+12*progress),Color(1,.77,.3,1-progress),2,true)
	if age >= 1.4:
		var time := minf(age-1.4,1.25)
		var fade := clampf((4.5-age)/1.2,0,1)
		for i in range(6):
			var side := -1.0 if i%2 == 0 else 1.0
			var velocity := Vector2(side*(50+i*12),-110-float(i%3)*35)
			var point := Vector2(0,-60)+velocity*time+Vector2(0,115)*time*time
			c.draw_set_transform(point,side*time*(1+i*.2))
			c.draw_texture_rect_region(PARTS,Rect2(-12,-16,24,32),Rect2((i%4)*362+8,420,346,310),Color(.7,.65,.6,fade))
		c.draw_set_transform(Vector2.ZERO)
		var dust := clampf((age-1.4)/3.1,0,1)
		c.draw_texture_rect_region(FX,Rect2(-150,-55,300,120),Rect2(mini(3,int(dust*4))*384,768,384,256),Color(.8,.65,.5,(1-dust)*.8))
