extends Node2D
@export var duration := 3.2
@export var pull_radius := 155.0
@export var pull_speed := 125.0
@export var damage_radius := 72.0
@export var tick_interval := .35
@export var tick_damage := .65
@export var bullet_radius := 125.0
@export var absorb_radius := 15.0
@export var bullet_acceleration := 550.0
var state: Dictionary = {}
func launch(pos: Vector2, owner_index: int) -> void:
	position = pos
	state = {"owner":owner_index,"life":duration,"tick":0.0}
	$Identity.text = "P%d 重力場" % (owner_index+1)
func _ready() -> void:
	var legendary = preload("res://scripts/visuals/gravity_legendary.gd").new()
	legendary.name = "LegendaryVisual"
	add_child(legendary)
	for entry in [["PullRing",pull_radius],["DamageRing",damage_radius],["Core",absorb_radius]]:
		var points := PackedVector2Array()
		for i in range(65): points.append(Vector2.from_angle(i*TAU/64)*entry[1])
		get_node(entry[0]).points = points
func step(dt: float, arena, players: Array, shots: Array, roster = null) -> void:
	state.life -= dt
	$LegendaryVisual.advance(duration-float(state.life),float(state.life),dt)
	queue_redraw()
	state.tick -= dt
	var tick: bool = state.tick <= 0
	if tick: state.tick = tick_interval
	for i in range(players.size()):
		if not (roster.hostile(state.owner,i) if roster != null else i != state.owner): continue
		var enemy = players[i]
		if enemy.state.hp <= 0: continue
		var offset: Vector2 = position-enemy.state.pos
		var distance := offset.length()
		if distance < pull_radius and distance > 4.0 and enemy.state.roll <= 0:
			arena.move_fighter(enemy.state,offset/distance*pull_speed*dt,enemy.radius)
			enemy.sync_visual()
		if tick and distance < damage_radius and not arena.line_blocked(position,enemy.state.pos): enemy.hurt(tick_damage)

	for shot in shots:
		var b: Dictionary = shot.state
		if b.dead or not (roster.hostile(state.owner,b.owner) if roster != null else b.owner != state.owner): continue
		var toward: Vector2 = position-b.pos
		var d := toward.length()
		if d < bullet_radius:
			if d < absorb_radius: b.dead = true
			else: b.velocity += toward/d*bullet_acceleration*dt
	modulate.a = clampf(state.life/.3,.0,1.0)

func _draw() -> void:
	if state.is_empty(): return
	var age := duration-float(state.life)
	var opening := clampf(age/.22,0.0,1.0)
	# Inward streams describe the persistent field without obscuring fighters or bullets.
	# The field's existing rings continue to communicate the actual gameplay radii.
	for arm in range(5):
		for segment in range(25):
			var t := segment/25.0
			var next_t := (segment+1)/25.0
			var angle := arm*TAU/5.0-age*2.2+t*2.8
			var next_angle := arm*TAU/5.0-age*2.2+next_t*2.8
			var a := Vector2.from_angle(angle)*lerpf(18.0,damage_radius*1.35,t)*opening
			var b := Vector2.from_angle(next_angle)*lerpf(18.0,damage_radius*1.35,next_t)*opening
			var strength := (1.0-t)*opening
			draw_line(a,b,Color(.49,.16,1.0,strength*.2),10.0*(1.0-t)+2.0,true)
			draw_line(a,b,Color(.77,.43,1.0,strength*.85),3.2,true)
			draw_line(a,b,Color(.9,.77,1.0,strength*.7),1.1,true)
	for i in range(32):
		var progress := fposmod(age*.8+i/32.0,1.0)
		var orbit := i*2.39996+age*.8+progress*2.0
		var distance := lerpf(pull_radius*.82,absorb_radius,progress)*opening
		var pos := Vector2.from_angle(orbit)*distance
		var alpha := sin(progress*PI)*.85*opening
		draw_line(pos,pos+Vector2.from_angle(orbit-.4)*(5.0+progress*6.0),Color(.85,.7,1.0,alpha),2.0,true)
	# A compact dark center leaves the surrounding playfield readable.
	draw_circle(Vector2.ZERO,absorb_radius*opening,Color(.025,.018,.055,.8*opening))
	var visuals = preload("res://scripts/catalog/weapon_visual_catalog.gd")
	var tex: Texture2D = visuals.texture(str(visuals.data.get("gravity_core","")))
	var size := 44.0*opening*(1.0+sin(age*6.0)*.07)
	draw_set_transform(Vector2.ZERO,age*.7)
	draw_texture_rect(tex,Rect2(Vector2.ONE*-size*.5,Vector2.ONE*size),false,Color(1,1,1,.85))
