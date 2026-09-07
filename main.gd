extends Node2D
# Migration M1: deterministic fixed-step local duel. All artwork/data are preserved separately.
var fighters: Array = []
var shots: Array = []
var walls: Array[Rect2] = [Rect2(240,160,80,85), Rect2(800,355,80,85), Rect2(515,250,90,90)]
var remaining := 90.0
var result := ""
var paused := false
var catalog: Dictionary
var hud: Label
var font := ThemeDB.fallback_font

func _ready() -> void:
	catalog = JSON.parse_string(FileAccess.get_file_as_string("res://data/catalog.json"))
	hud = Label.new()
	hud.position = Vector2(24,12)
	hud.add_theme_font_size_override("font_size",18)
	add_child(hud)
	reset_round()

func reset_round() -> void:
	shots.clear()
	fighters.clear()
	remaining = 90
	result = ""
	paused = false
	for i in range(2):
		fighters.append({"pos":Vector2(170+780*i,300),"hp":8.0,"angle":0.0,"shot":0.0,"roll":0.0,"dodge":0.0,"slash":0.0,"melee":0.0,"inv":0.0,"reload":0.0,"clip":8,"reserve":40,"dir":Vector2.RIGHT,"gun":0})

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_ENTER and result != "":
		reset_round()
	if event.keycode == KEY_ESCAPE:
		paused = not paused
	if paused or result != "":
		return
	for i in range(2):
		var p: Dictionary = fighters[i]
		if event.keycode == [KEY_E,KEY_O][i]:
			p.gun = 1 - p.gun
		if event.keycode == [KEY_R,KEY_P][i] and p.reload <= 0 and p.clip < 8 and p.reserve > 0:
			p.reload = 1.15
		if event.keycode == [KEY_SPACE,KEY_K][i] and p.dodge <= 0:
			p.roll = .26
			p.dodge = 1.65
		if event.keycode == [KEY_V,KEY_L][i] and p.melee <= 0 and p.reload <= 0 and p.roll <= 0:
			p.melee = 1.1
			p.slash = .16
			p.shot = maxf(p.shot,.3)
			var removed := 0
			for b in shots:
				var delta: Vector2 = b.pos - p.pos
				if b.owner != i and not b.dead and delta.length() <= 64 and absf(wrapf(delta.angle()-p.angle,-PI,PI)) <= PI/3 and removed < 3:
					b.dead = true
					removed += 1
			var enemy: Dictionary = fighters[1-i]
			var delta: Vector2 = enemy.pos-p.pos
			if delta.length() < 64 and absf(wrapf(delta.angle()-p.angle,-PI,PI)) <= PI/3:
				hurt(enemy,.6)

func solid(pos: Vector2, radius: float) -> bool:
	for wall in walls:
		var closest := Vector2(clampf(pos.x,wall.position.x,wall.end.x),clampf(pos.y,wall.position.y,wall.end.y))
		if pos.distance_to(closest) < radius:
			return true
	return false

func move_fighter(p: Dictionary, delta: Vector2) -> void:
	var steps := maxi(1,ceili(delta.length()/5))
	for n in range(steps):
		var dest: Vector2 = p.pos + Vector2(delta.x/steps,0)
		dest.x = clampf(dest.x,60,1060)
		if not solid(dest,14): p.pos = dest
		dest = p.pos + Vector2(0,delta.y/steps)
		dest.y = clampf(dest.y,82,540)
		if not solid(dest,14): p.pos = dest

func hurt(p: Dictionary, amount: float) -> void:
	if p.inv > 0 or p.roll > 0: return
	p.hp = maxf(0,p.hp-amount)
	p.inv = .22

func _physics_process(dt: float) -> void:
	if not paused and result == "":
		remaining -= dt
		for i in range(2):
			var p: Dictionary = fighters[i]
			for timer in ["shot","roll","dodge","slash","melee","inv"]:
				p[timer] = maxf(0,p[timer]-dt)
			if p.reload > 0:
				p.reload = maxf(0,p.reload-dt)
				if p.reload == 0:
					var amount := mini(8-p.clip,p.reserve)
					p.clip += amount
					p.reserve -= amount
			var keys: Array = [KEY_A,KEY_D,KEY_W,KEY_S] if i == 0 else [KEY_LEFT,KEY_RIGHT,KEY_UP,KEY_DOWN]
			var axis := Vector2(float(Input.is_physical_key_pressed(keys[1]))-float(Input.is_physical_key_pressed(keys[0])),float(Input.is_physical_key_pressed(keys[3]))-float(Input.is_physical_key_pressed(keys[2]))).normalized()
			p.angle = (fighters[1-i].pos-p.pos).angle()
			if p.roll <= 0 and axis.length() > 0: p.dir = axis
			move_fighter(p,p.dir*590*dt if p.roll > 0 else axis*205*dt)
			if Input.is_physical_key_pressed(KEY_F if i == 0 else KEY_J) and p.shot <= 0 and p.reload <= 0 and p.roll <= 0 and p.clip > 0:
				p.clip -= 1
				p.shot = .28 if p.gun == 0 else .45
				shots.append({"pos":p.pos+Vector2.from_angle(p.angle)*24,"velocity":Vector2.from_angle(p.angle)*420,"owner":i,"life":2.8,"bounce":2 if p.gun == 1 else 0,"dead":false})
		for b in shots:
			b.life -= dt
			var steps := maxi(1,ceili(b.velocity.length()*dt/5))
			for n in range(steps):
				if b.dead: break
				var previous: Vector2 = b.pos
				b.pos += b.velocity*dt/steps
				if b.pos.x < 32 or b.pos.x > 1088 or b.pos.y < 60 or b.pos.y > 570 or solid(b.pos,4):
					if b.bounce > 0:
						b.bounce -= 1
						if b.pos.x < 32 or b.pos.x > 1088 or solid(Vector2(b.pos.x,previous.y),4): b.velocity.x *= -1
						else: b.velocity.y *= -1
						b.pos = previous
					else: b.dead = true
				elif b.pos.distance_to(fighters[1-b.owner].pos) < 18:
					hurt(fighters[1-b.owner],1)
					b.dead = true
		shots = shots.filter(func(b): return not b.dead and b.life > 0)
		if remaining <= 0 or fighters[0].hp <= 0 or fighters[1].hp <= 0:
			result = "DRAW" if fighters[0].hp == fighters[1].hp else ("P1 WINS" if fighters[0].hp > fighters[1].hp else "P2 WINS")
	hud.text = "P1 HP %.1f  AMMO %d/%d   |   %02d sec   |   P2 HP %.1f  AMMO %d/%d\nP1 WASD / F fire / SPACE dodge / V melee / R reload / E gun\nP2 arrows / J fire / K dodge / L melee / P reload / O gun   ESC pause" % [fighters[0].hp,fighters[0].clip,fighters[0].reserve,maxi(0,int(remaining)),fighters[1].hp,fighters[1].clip,fighters[1].reserve]
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(0,0,1120,600),Color("303532"))
	for wall in walls: draw_rect(wall,Color("858975"))
	for i in range(fighters.size()):
		var p: Dictionary = fighters[i]
		var color := Color("f39545") if i == 0 else Color("64b5ee")
		draw_circle(p.pos,14,color)
		draw_line(p.pos,p.pos+Vector2.from_angle(p.angle)*27,Color.WHITE,5)
		if p.slash > 0: draw_arc(p.pos,64,p.angle-PI/3,p.angle+PI/3,16,color,4)
		draw_string(font,p.pos+Vector2(-15,-23),"P%d %s" % [i+1,"B" if p.gun else "C"],HORIZONTAL_ALIGNMENT_LEFT,-1,16)
	for b in shots: draw_circle(b.pos,4,Color("ffe1a0") if b.owner == 0 else Color("a2dfff"))
	if paused or result != "": draw_string(font,Vector2(360,220),"PAUSED" if paused else result+" / ENTER restart",HORIZONTAL_ALIGNMENT_LEFT,-1,28)
