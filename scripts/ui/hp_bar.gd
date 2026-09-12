extends Control
@export var segment_color := Color("f39545")
var opacities: Array[float] = []
var current_hp := -1.0
var maximum_hp := -1.0

func refresh(hp: float, maximum: float) -> void:
	if hp == current_hp and maximum == maximum_hp: return
	current_hp = hp
	maximum_hp = maximum
	opacities.clear()
	for i in range(maxi(0,int(maximum))): opacities.append(clampf(hp-i,0.0,1.0)*.8+.2)
	queue_redraw()

func _draw() -> void:
	if opacities.is_empty(): return
	draw_rect(Rect2(Vector2.ZERO,size),Color("37434a"))
	var ratio := clampf(current_hp / maximum_hp,0,1) if maximum_hp > 0 else 0.0
	draw_rect(Rect2(Vector2.ZERO,Vector2(size.x*ratio,size.y)),segment_color)
