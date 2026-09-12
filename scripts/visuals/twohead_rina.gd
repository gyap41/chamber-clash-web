extends RefCounted
# Fixed UV cutouts from one approved drawing. No frame-to-frame redrawing.
const TEXTURE = preload("res://tests/fixtures/art/legacy-rina-twohead/rina.png")
const SCALE = 56.0/662.0
const BODY = [Vector2(0,0),Vector2(525,0),Vector2(525,592),Vector2(402,592),Vector2(390,614),Vector2(335,630),Vector2(260,639),Vector2(180,624),Vector2(0,624)]
const LEFT_SHOE = [Vector2(179,618),Vector2(270,634),Vector2(271,662),Vector2(176,662)]
const RIGHT_SHOE = [Vector2(326,626),Vector2(394,596),Vector2(415,637),Vector2(359,653)]

static func shoe_offset(phase: float, foot: int, direction: Vector2) -> Vector2:
	var angle := phase*TAU/6.0+foot*PI
	# Opposite contact phases; lift only the returning shoe.
	return direction*cos(angle)*2.8+Vector2(0,-maxf(0.0,sin(angle))*2.5)

static func part(canvas: Node2D, points: Array, offset: Vector2, color: Color) -> void:
	var polygon := PackedVector2Array()
	var uv := PackedVector2Array()
	for point: Vector2 in points:
		polygon.append((point-Vector2(262.5,662))*SCALE+Vector2(0,15)+offset)
		uv.append(point/Vector2(525,662))
	canvas.draw_polygon(polygon,PackedColorArray([color]),uv,TEXTURE)

static func dive_pose(direction: Vector2, roll_progress: float) -> Transform2D:
	var base := Transform2D.IDENTITY
	if roll_progress >= 0:
		var time := roll_progress*.38
		var lean := 0.0
		var lift := 0.0
		var squash := Vector2.ONE
		if time < .04:
			var u := time/.04
			lean = u*.25
			squash = Vector2(1+u*.08,1-u*.16)
		elif time < .26:
			var u := (time-.04)/.22
			lean = lerpf(.25,1.25,sin(u*PI*.5))
			lift = sin(u*PI)*12.0
			squash = Vector2(1.0,.88)
		else:
			var u := (time-.26)/.12
			lean = 1.25*(1-u)*(1-u)
			squash = Vector2(1+sin(u*PI)*.13,1-sin(u*PI)*.2)
		# Tilt head toward travel without an upside-down revolution.
		var tilt_sign := -1.0 if direction.x < -.1 else 1.0
		lean *= lerpf(.2,1.0,absf(direction.x))
		base *= Transform2D(0.0,Vector2(0,-lift))*Transform2D(lean*tilt_sign,squash,0.0,Vector2.ZERO)
	return base

static func render(canvas: Node2D, base: Transform2D, walking: bool, phase: float,
		direction: Vector2, roll_progress: float, color: Color) -> void:
	var bob := -absf(sin(phase*TAU/6.0))*1.2 if walking else 0.0
	base *= dive_pose(direction,roll_progress)
	canvas.draw_set_transform_matrix(base)
	part(canvas,RIGHT_SHOE,shoe_offset(phase,1,direction) if walking else Vector2.ZERO,color)
	part(canvas,LEFT_SHOE,shoe_offset(phase,0,direction) if walking else Vector2.ZERO,color)
	part(canvas,BODY,Vector2(0,bob),color)
