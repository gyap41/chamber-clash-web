extends ColorRect
const WORKSHOP_COVER = preload("res://assets/first-workshop/cover.png")
@export var corner_texture: Texture2D = preload("res://assets/first-workshop/environment/corner-cap.tres")
@export var surface_texture: Texture2D
@export var face_texture: Texture2D
var cover_texture: Texture2D = WORKSHOP_COVER
var tile_size := 48
var face_repeat := 96
var cap_height := 12.0
var pier_width := 32.0
func apply_theme(theme) -> void:
	cover_texture = theme.cover_texture
	corner_texture = theme.corner
	tile_size = theme.tile_size
	face_repeat = theme.face_repeat
	cap_height = minf(theme.cap_height,size.y*.5)
	pier_width = minf(theme.pier_width,size.x*.5)
func _draw() -> void:
	if surface_texture == null:
		if cover_texture != null: draw_texture_rect(cover_texture,Rect2(Vector2.ZERO,size),false)
		return
	# Fit the complete cross-section so both metal rails survive on narrow walls.
	var surface_size := size
	if size.y > size.x:
		draw_set_transform(Vector2(size.x,0),PI/2)
		surface_size = Vector2(size.y,size.x)
	for x in range(0,int(ceil(surface_size.x)),tile_size):
		var width := minf(tile_size,surface_size.x-x)
		draw_texture_rect_region(surface_texture,Rect2(x,0,width,surface_size.y),Rect2(Vector2.ZERO,Vector2(width/tile_size,1)*surface_texture.get_size()))
	draw_set_transform(Vector2.ZERO)
	if face_texture != null:
		# The upright inner face fits inside the solid footprint; the cap remains above it.
		for x in range(0,int(ceil(size.x)),face_repeat):
			var width := minf(face_repeat,size.x-x)
			draw_texture_rect_region(face_texture,Rect2(x,cap_height,width,size.y-cap_height),Rect2(Vector2.ZERO,Vector2(width/face_repeat,1)*face_texture.get_size()),Color(.72,.73,.72))
		draw_line(Vector2(0,cap_height),Vector2(size.x,cap_height),Color("b6b39b"),2)
		draw_line(Vector2(0,size.y-1),Vector2(size.x,size.y-1),Color("171d1e"),3)
		# End piers carry the upper wall down to the side wall, hiding the butt joint.
		for x in [0.0,size.x-pier_width]:
			draw_texture_rect(face_texture,Rect2(x,cap_height,pier_width,size.y-cap_height),false,Color(.85,.84,.78))
			if corner_texture != null: draw_texture_rect(corner_texture,Rect2(x,0,pier_width,cap_height),false)
			draw_line(Vector2(x+1,cap_height),Vector2(x+1,size.y),Color("8e8b75"),2)
	elif size.x > size.y:
		for x in [0.0,size.x-size.y]:
			if corner_texture != null: draw_texture_rect(corner_texture,Rect2(x,0,size.y,size.y),false)
# ColorRect is both the editable visual and the source of the M1 collision rectangle.
# Axis-aligned walls only: resize with layout handles; do not rotate/scale.
func collision_rect() -> Rect2:
	return Rect2(position,size)
