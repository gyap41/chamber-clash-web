extends RefCounted
# Explicit registration; faint alpha outside the silhouettes is not their size.
const ORDNANCE = preload("res://assets/sprites/boss/foundry-spinner/cannon-v1/ordnance.png")
const IMPACT = preload("res://assets/sprites/boss/foundry-spinner/cannon-v1/impact.png")

static func muzzle_point(angle: float, heavy: bool) -> Vector2:
	# The drawn ports sit above the ground-plane collision origin.
	var axis := Vector2.from_angle(angle)
	return Vector2(axis.x*62,axis.y*24-67) if heavy else Vector2(axis.x*72,axis.y*23-38)

static func projectile(c: Node2D, heavy: bool, age: float = 0.0) -> void:
	var source := Rect2(684,240,456,225) if heavy else Rect2(235,280,154,155)
	var size := Vector2(56,28) if heavy else Vector2(17,17)
	if heavy:
		# Short, bounded directional wake; the bright metal core remains readable.
		for layer in range(3):
			c.draw_line(Vector2(-90,0),Vector2(-10,0),Color(1,.32+layer*.18,.08,.10+layer*.10),26-layer*8,true)
		c.draw_circle(Vector2.ZERO,24,Color(1,.48,.12,.12))
		for n in range(7):
			var travel := fposmod(age*5+n/7.0,1.0)
			var point := Vector2(-28-travel*64,sin(n*2.4)*travel*15)
			c.draw_line(point,point+Vector2(8,0),Color(1,.7,.25,(1-travel)*.7),2,true)
	c.draw_line(Vector2(-size.x*.5,0),Vector2(-size.x,0),Color(1,.65,.2,.5),3,true)
	c.draw_texture_rect_region(ORDNANCE,Rect2(-size*.5,size),source)

static func muzzle(c: Node2D, at: Vector2, angle: float, heavy: bool, age: float) -> void:
	var source := Rect2(640,680,580,490) if heavy else Rect2(140,760,400,350)
	var pivot := Vector2(210,240) if heavy else Vector2(120,170)
	var scale := .28 if heavy else .15
	c.draw_set_transform(at,angle)
	c.draw_texture_rect_region(ORDNANCE,Rect2(-pivot*scale,source.size*scale),source,Color(1,1,1,1-age/(.24 if heavy else .18)))
	c.draw_set_transform(Vector2.ZERO)

static func impact(c: Node2D, age: float, heavy: bool) -> void:
	var progress := clampf(age/.64,0,1)
	var frame := mini(7,int(progress*8))
	var boundaries := [0,443,887,1330,1774]
	var column := frame%4
	var source := Rect2(boundaries[column],443*(frame/4),boundaries[column+1]-boundaries[column],444 if frame >= 4 else 443)
	var size := 216.0 if heavy else 76.0
	if heavy:
		var fade := 1.0-progress
		c.draw_circle(Vector2.ZERO,32+progress*35,Color(1,.7,.3,pow(fade,5)*.32))
		c.draw_arc(Vector2.ZERO,16+progress*92,0,TAU,64,Color(1,.64,.25,fade*fade*.6),4*fade,true)
		for n in range(12):
			var axis := Vector2.from_angle(n*TAU/12.0+.2)
			c.draw_line(axis*(24+progress*75),axis*(30+progress*94),Color(1,.72,.35,fade*fade*.7),2,true)
	c.draw_texture_rect_region(IMPACT,Rect2(-size*.5,-size*.5,size,size),source,Color(1,1,1,1-smoothstep(.6,1.0,progress)))
