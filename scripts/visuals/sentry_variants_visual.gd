extends RefCounted
# Distinct, articulated placeholders; production sprites are tracked in the art ledger.
static func paint(canvas: Node2D, view: Dictionary) -> void:
	var id: String = view.get("enemy_id","")
	var ring := id == "ring_sentry"
	var ram := id == "ram_sentry"
	var death := float(view.get("death_progress",0))
	var alpha := 1-death
	var angle := float(view.get("angle",0))
	var charge := 0.0
	if view.get("phase","") == "windup": charge = 1-float(view.remaining)/float(view.windup)
	canvas.draw_set_transform(Vector2.ZERO,0,Vector2(1,.35))
	canvas.draw_circle(Vector2.ZERO,23 if ring or ram else 16,Color(0,0,0,.3*alpha))
	canvas.draw_set_transform(Vector2(0,-16+death*14))
	var body := Color(.46,.49,.37,alpha) if ring else Color(.65,.39,.22,alpha) if ram else Color(.44,.60,.58,alpha)
	for side in [-1,1]:
		var stride := sin(float(view.get("gait",0))+ (PI if side < 0 else 0))*5*float(view.get("motion",0))
		canvas.draw_line(Vector2(side*10,5),Vector2(side*15,16+stride),Color(.23,.23,.20,alpha),6,true)
	canvas.draw_circle(Vector2.ZERO,22 if ring or ram else 15,Color(.15,.17,.16,alpha))
	canvas.draw_circle(Vector2(0,-2),19 if ring or ram else 12,body)
	if ring:
		for n in range(3,14):
			var axis := Vector2.from_angle(angle+n*TAU/16)
			canvas.draw_line(axis*18,axis*(27+charge*4),Color(.28,.29,.24,alpha),5,true)
		canvas.draw_arc(Vector2.ZERO,15,0,TAU,24,Color(.92,.75,.39,alpha),3,true)
	elif ram:
		var forward := Vector2.from_angle(angle)
		var across := forward.orthogonal()
		var front := forward*(21-charge*4)
		canvas.draw_line(front-across*19,front+across*19,Color(.88,.75,.53,alpha),9,true)
	else:
		canvas.draw_line(Vector2.ZERO,Vector2.from_angle(angle)*(19+charge*5),Color(.83,.84,.73,alpha),5,true)
	canvas.draw_circle(Vector2(0,-6),4,Color(1,.65+charge*.3,.25,alpha))
	if float(view.get("hit",0)) > 0: canvas.draw_circle(Vector2(0,-6),6,Color(1,1,1,alpha))
	canvas.draw_set_transform(Vector2.ZERO)
