extends Node2D
# Presentation only. Geometry follows legacy-web/dist/render.js drawArena().
@export var band_color := Color("de683b40")
@export var boundary_color := Color("ef914c")
var inset := 0.0

func refresh(value: float) -> void:
	if is_equal_approx(inset,value): return
	inset = value
	visible = inset > 0.0
	queue_redraw()

func safe_rect() -> Rect2:
	return Rect2(inset+25.0,inset*.58+25.0,1120.0-2.0*inset-50.0,600.0-2.0*inset*.58-50.0)

func _draw() -> void:
	if inset <= 0.0: return
	draw_rect(Rect2(28,35,inset,538),band_color)
	draw_rect(Rect2(1092-inset,35,inset,538),band_color)
	draw_rect(Rect2(28,35,1064,inset*.58),band_color)
	draw_rect(Rect2(28,572-inset*.58,1064,inset*.58),band_color)
	var rect := safe_rect()
	# Canvas setLineDash([8,8]): preserve its phase around the whole rectangle.
	var corners := [rect.position,Vector2(rect.end.x,rect.position.y),rect.end,Vector2(rect.position.x,rect.end.y),rect.position]
	var distance := 0.0
	for edge in range(4):
		var start: Vector2 = corners[edge]
		var end: Vector2 = corners[edge+1]
		var length := start.distance_to(end)
		var offset := 0.0
		while offset < length:
			var phase := fmod(distance,16.0)
			var segment := minf(8.0-fmod(phase,8.0),length-offset)
			if phase < 8.0:
				draw_line(start.lerp(end,offset/length),start.lerp(end,(offset+segment)/length),boundary_color,1.0)
			offset += segment
			distance += segment
