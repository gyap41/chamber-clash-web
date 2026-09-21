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
var wall_rise := 0.0
var upper_extension := 0.0
var joint_caps: Array[Rect2] = []
var shared_surface := false

func connect_faces(walls: Array) -> void:
	upper_extension = 0.0
	joint_caps.clear()
	z_index = 0
	if surface_texture == null or face_texture != null or size.y <= size.x: return
	z_index = 1 # Connected side coping covers face endpoints independent of input order.
	for other in walls:
		if other.surface_texture == null or other.size.x <= other.size.y: continue
		var rect: Rect2 = other.collision_rect()
		var own := collision_rect()
		var stacked := is_equal_approx(rect.end.y,own.position.y) and rect.position.x <= own.position.x and rect.end.x >= own.end.x
		var adjacent := (is_equal_approx(rect.position.x,own.end.x) or is_equal_approx(rect.end.x,own.position.x)) and rect.end.y > own.position.y and rect.end.y <= own.end.y
		var below_face := other.face_texture != null and is_equal_approx(rect.position.y,own.end.y) and rect.position.x <= own.position.x and rect.end.x >= own.end.x
		if not stacked and not adjacent and not below_face: continue
		var top: float = rect.position.y-(other.wall_rise if other.face_texture != null else 0.0)-position.y
		upper_extension = maxf(upper_extension,-top)
		var cap := Rect2(0,top,size.x,other.cap_height if other.face_texture != null else other.size.y)
		if cap not in joint_caps: joint_caps.append(cap)
	queue_redraw()
func apply_theme(theme) -> void:
	shared_surface = theme.connected_walls
	cover_texture = theme.cover_texture
	corner_texture = theme.corner
	tile_size = theme.tile_size
	face_repeat = theme.face_repeat
	cap_height = minf(theme.cap_height,size.y*.5)
	pier_width = minf(theme.pier_width,size.x*.5)
	wall_rise = theme.wall_rise
func _draw() -> void:
	if shared_surface and surface_texture != null: return
	if surface_texture == null:
		if cover_texture != null: draw_texture_rect(cover_texture,Rect2(Vector2.ZERO,size),false)
		return
	# Fit the complete cross-section so both metal rails survive on narrow walls.
	var surface_size := size
	if size.y > size.x:
		draw_set_transform(Vector2(size.x,-upper_extension),PI/2)
		surface_size = Vector2(size.y+upper_extension,size.x)
	for x in range(0,int(ceil(surface_size.x)),tile_size):
		var width := minf(tile_size,surface_size.x-x)
		draw_texture_rect_region(surface_texture,Rect2(x,0,width,surface_size.y),Rect2(Vector2.ZERO,Vector2(width/tile_size,1)*surface_texture.get_size()))
	draw_set_transform(Vector2.ZERO)
	for cap in joint_caps:
		# A shared cap covers the seam where the vertical coping turns horizontally.
		if wall_rise > 0 and is_equal_approx(cap.size.y,size.x):
			draw_texture_rect(surface_texture,cap,false)
		elif corner_texture != null: draw_texture_rect(corner_texture,cap,false)
	if face_texture != null:
		if wall_rise > 0:
			draw_raised_face()
			return
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
	elif size.x > size.y and wall_rise == 0:
		for x in [0.0,size.x-size.y]:
			if corner_texture != null: draw_texture_rect(corner_texture,Rect2(x,0,size.y,size.y),false)
# ColorRect is both the editable visual and the source of the M1 collision rectangle.
# Axis-aligned walls only: resize with layout handles; do not rotate/scale.
func collision_rect() -> Rect2:
	return Rect2(position,size)

func draw_raised_face() -> void:
	# Raise the cap above the footprint; the face still meets the original floor edge.
	var top := -wall_rise
	var face_top := top+cap_height
	for x in range(0,int(ceil(size.x)),face_repeat):
		var width := minf(face_repeat,size.x-x)
		draw_texture_rect_region(face_texture,Rect2(x,face_top,width,size.y-face_top),Rect2(Vector2.ZERO,Vector2(width/face_repeat,1)*face_texture.get_size()),Color(.77,.76,.71))
	for x in range(0,int(ceil(size.x)),tile_size):
		var width := minf(tile_size,size.x-x)
		draw_texture_rect_region(surface_texture,Rect2(x,top,width,cap_height),Rect2(Vector2.ZERO,Vector2(width/tile_size,1)*surface_texture.get_size()))
	for x in [0.0,size.x-pier_width]:
		draw_texture_rect(face_texture,Rect2(x,face_top,pier_width,size.y-face_top),false,Color(.90,.86,.76))
		if corner_texture != null: draw_texture_rect(corner_texture,Rect2(x,top,pier_width,cap_height),false)
		draw_line(Vector2(x+1,face_top),Vector2(x+1,size.y),Color("b7ad90"),2)
	draw_line(Vector2(0,face_top),Vector2(size.x,face_top),Color("c9bfa3"),2)
	draw_line(Vector2(0,size.y-1),Vector2(size.x,size.y-1),Color("161c1e"),3)
