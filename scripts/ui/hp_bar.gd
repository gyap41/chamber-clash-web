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
	var gap := 3.0
	var skew := tan(deg_to_rad(12.0))*size.y
	var width := (size.x-skew-gap*(opacities.size()-1))/opacities.size()
	for i in range(opacities.size()):
		var x := i*(width+gap)
		var color := segment_color
		color.a *= opacities[i]
		draw_colored_polygon(PackedVector2Array([Vector2(x+skew,0),Vector2(x+width+skew,0),Vector2(x+width,size.y),Vector2(x,size.y)]),color)
