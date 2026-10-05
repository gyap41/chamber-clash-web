extends Control
var shape: Array = [Vector2i.ZERO]
var texture: Texture2D
var offset := Vector2.ZERO
var tint := Color(.5,1,.85,.35)
static func art_rect(cells: Array,unit: float) -> Rect2:
	# Largest fully occupied rectangle keeps L-shaped art out of other items' cells.
	var best := Rect2(0,0,unit,unit)
	for start in cells:
		for w in range(1,7):
			for h in range(1,7):
				var valid := true
				for y in range(h):
					for x in range(w):
						if start+Vector2i(x,y) not in cells: valid = false
				if valid and w*h*unit*unit>best.get_area(): best = Rect2(Vector2(start)*unit,Vector2(w,h)*unit)
	return best.grow(-5)
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
func _draw() -> void:
	for cell in shape:
		draw_rect(Rect2(offset+Vector2(cell)*60,Vector2(58,58)),tint)
		draw_rect(Rect2(offset+Vector2(cell)*60,Vector2(58,58)),Color(tint.r,tint.g,tint.b,.8),false,2)
	if texture != null:
		var rect: Rect2 = art_rect(shape,60)
		var fit: Vector2 = texture.get_size()*minf(rect.size.x/texture.get_width(),rect.size.y/texture.get_height())
		draw_texture_rect(texture,Rect2(offset+rect.position+(rect.size-fit)/2,fit),false,Color(1,1,1,.85))
