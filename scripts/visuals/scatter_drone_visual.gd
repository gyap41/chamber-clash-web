extends RefCounted
# Art prototype: separate casing, rotating muzzle, fins and floor shadow.
static func paint(canvas: Node2D, view: Dictionary) -> void:
	var death := float(view.get("death_progress",0))
	var alpha := 1.0-death
	var time := float(view.get("visual_time",0))
	var center := Vector2(0,-17+sin(time*3)*2+death*16)
	var angle := float(view.get("angle",0))
	var charge := 0.0
	if view.get("phase","") == "windup": charge = 1.0-float(view.remaining)/float(view.windup)
	var recoil := 0.0
	if view.get("phase","") == "spit": recoil = clampf((float(view.remaining)-.30)/.18,0,1)*4
	canvas.draw_set_transform(Vector2.ZERO,0,Vector2(1,.35))
	canvas.draw_circle(Vector2.ZERO,23,Color(0,0,0,.25*alpha))
	canvas.draw_set_transform(center)
	for side in [-1,1]:
		var x: float = side*(22+charge*5)
		canvas.draw_rect(Rect2(x-5,-9,10,18),Color(.40,.33,.23,alpha))
		canvas.draw_line(Vector2(x,-6),Vector2(x,6),Color(.83,.70,.44,alpha),2)
	canvas.draw_circle(Vector2.ZERO,21,Color(.17,.19,.18,alpha))
	canvas.draw_circle(Vector2(0,-2),18,Color(.63,.57,.43,alpha))
	canvas.draw_arc(Vector2(0,-2),15,PI,TAU,18,Color(.88,.80,.60,alpha),3,true)
	var muzzle := Vector2.from_angle(angle)
	canvas.draw_line(muzzle*6,muzzle*(29-recoil),Color(.22,.24,.22,alpha),10,true)
	canvas.draw_circle(muzzle*(27-recoil),4,Color(1,.61+charge*.25,.20,alpha))
	canvas.draw_circle(Vector2(-5,-7),4,Color(1,.70+charge*.25,.30,alpha))
	if float(view.get("hit",0)) > 0: canvas.draw_arc(Vector2.ZERO,20,0,TAU,24,Color(1,1,1,alpha),2,true)
	canvas.draw_set_transform(Vector2.ZERO)
