extends Node2D
@export var max_hp: float = 8.0
@export var move_speed: float = 205.0
@export var roll_speed: float = 590.0
@export var radius: float = 14.0
@export var magazine_size: int = 8
@export var initial_reserve: int = 40
@export var reload_duration: float = 1.15
@export var dodge_duration: float = 0.26
@export var dodge_cooldown: float = 1.65
@export var melee_cooldown: float = 1.1
@export var melee_range: float = 64.0
@export var melee_damage: float = 0.6
@export var melee_limit: int = 3
@export var normal_interval: float = 0.28
@export var bounce_interval: float = 0.45
var state: Dictionary = {}
func reset(spawn: Vector2) -> void:
	state = {"pos":spawn,"hp":max_hp,"angle":0.0,"shot":0.0,"roll":0.0,"dodge":0.0,"slash":0.0,"melee":0.0,"inv":0.0,"reload":0.0,"clip":magazine_size,"reserve":initial_reserve,"dir":Vector2.RIGHT,"gun":0}
	sync_visual()
func hurt(amount: float) -> void:
	if state.inv > 0 or state.roll > 0: return
	state.hp = maxf(0,state.hp-amount)
	state.inv = .22
func handle_key(key: int, i: int, shots: Array, enemy) -> void:
	var p = state
	if key == [KEY_E,KEY_O][i]: p.gun = 1-p.gun
	if key == [KEY_R,KEY_P][i] and p.reload <= 0 and p.clip < magazine_size and p.reserve > 0: p.reload = reload_duration
	if key == [KEY_SPACE,KEY_K][i] and p.dodge <= 0:
		p.roll = dodge_duration
		p.dodge = dodge_cooldown
	if key == [KEY_V,KEY_L][i] and p.melee <= 0 and p.reload <= 0 and p.roll <= 0:
		p.melee = melee_cooldown
		p.slash = .16
		p.shot = maxf(p.shot,.3)
		var removed := 0
		for bullet in shots:
			var b = bullet.state
			var offset: Vector2 = b.pos-p.pos
			if b.owner != i and not b.dead and offset.length() <= melee_range and absf(wrapf(offset.angle()-p.angle,-PI,PI)) <= PI/3 and removed < melee_limit:
				b.dead = true
				removed += 1
		var offset: Vector2 = enemy.state.pos-p.pos
		if offset.length() < melee_range and absf(wrapf(offset.angle()-p.angle,-PI,PI)) <= PI/3: enemy.hurt(melee_damage)
func step(dt: float, i: int, enemy, arena) -> bool:
	var p = state
	for timer in ["shot","roll","dodge","slash","melee","inv"]: p[timer] = maxf(0,p[timer]-dt)
	if p.reload > 0:
		p.reload = maxf(0,p.reload-dt)
		if p.reload == 0:
			var amount := mini(magazine_size-p.clip,p.reserve)
			p.clip += amount
			p.reserve -= amount
	var keys: Array = [KEY_A,KEY_D,KEY_W,KEY_S] if i == 0 else [KEY_LEFT,KEY_RIGHT,KEY_UP,KEY_DOWN]
	var axis := Vector2(float(Input.is_physical_key_pressed(keys[1]))-float(Input.is_physical_key_pressed(keys[0])),float(Input.is_physical_key_pressed(keys[3]))-float(Input.is_physical_key_pressed(keys[2]))).normalized()
	p.angle = (enemy.state.pos-p.pos).angle()
	if p.roll <= 0 and axis.length() > 0: p.dir = axis
	arena.move_fighter(p,p.dir*roll_speed*dt if p.roll > 0 else axis*move_speed*dt,radius)
	sync_visual()
	return Input.is_physical_key_pressed(KEY_F if i == 0 else KEY_J) and can_fire()
func can_fire() -> bool:
	return state.shot <= 0 and state.reload <= 0 and state.roll <= 0 and state.clip > 0
func consume_shot() -> void:
	state.clip -= 1
	state.shot = normal_interval if state.gun == 0 else bounce_interval
func sync_visual() -> void:
	position = state.pos
	$Aim.rotation = state.angle
	$Identity.text = "%s %s" % [name,"B" if state.gun else "C"]
	$Slash.visible = state.slash > 0
	$Slash.rotation = state.angle
