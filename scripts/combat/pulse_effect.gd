extends Node2D
@export var duration := .45
@export var expansion_speed := 900.0
var age := 0.0
func _ready() -> void:
	var points := PackedVector2Array()
	for i in range(65): points.append(Vector2.from_angle(i*TAU/64))
	$Ring.points = points
func step(dt: float) -> bool:
	age += dt
	$Ring.scale = Vector2.ONE*(12.0+age*expansion_speed)
	$Ring.width = 3.0/maxf(1.0,$Ring.scale.x)
	modulate.a = maxf(0.0,1.0-age/duration)
	return age >= duration
