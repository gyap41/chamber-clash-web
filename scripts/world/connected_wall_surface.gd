extends Node2D
# Presentation union only. Collision remains the authored wall rectangles.
var tops: Array[Rect2] = []
var faces: Array[Rect2] = []
var boundaries: Array[Dictionary] = []
var theme
func configure(walls: Array, material_theme) -> void:
	tops.clear()
	faces.clear()
	theme = material_theme
	var front_returns: Array[Rect2] = []
	for wall in walls:
		if wall.surface_texture == null: continue
		var rect: Rect2 = wall.collision_rect()
		if wall.face_texture != null:
			var y: float = rect.position.y-wall.wall_rise
			tops.append(Rect2(rect.position.x,y,rect.size.x,wall.cap_height))
			var face := Rect2(rect.position.x,y+wall.cap_height,rect.size.x,rect.end.y-y-wall.cap_height)
			# At a return ending on this same floor edge, the front continues
			# through the side wall thickness. A continuing side wall stays a top.
			for side in walls:
				if side.surface_texture == null or side.face_texture != null: continue
				var side_rect: Rect2 = side.collision_rect()
				if side_rect.size.y <= side_rect.size.x or not is_equal_approx(side_rect.end.y,rect.end.y): continue
				if is_equal_approx(side_rect.end.x,rect.position.x):
					front_returns.append(Rect2(side_rect.position.x,face.position.y,side_rect.size.x,face.size.y))
					face.position.x = side_rect.position.x
					face.size.x += side_rect.size.x
				elif is_equal_approx(side_rect.position.x,rect.end.x):
					front_returns.append(Rect2(side_rect.position.x,face.position.y,side_rect.size.x,face.size.y))
					face.size.x += side_rect.size.x
			faces.append(face)
		else:
			if rect.size.y > rect.size.x:
				rect.position.y -= wall.upper_extension
				rect.size.y += wall.upper_extension
			tops.append(rect)
			for cap in wall.joint_caps:
				tops.append(Rect2(wall.position+cap.position,cap.size))
	# Only a terminating return becomes a front; continuing side coping wins
	# at the upper corner where it reaches the north wall cap.
	for face in front_returns:
		var remaining: Array[Rect2] = []
		for top in tops: remaining.append_array(subtract_rect(top,face))
		tops = remaining
	for top in tops:
		var remaining_faces: Array[Rect2] = []
		for face in faces: remaining_faces.append_array(subtract_rect(face,top))
		faces = remaining_faces
	boundaries = outline(tops)
	queue_redraw()
static func subtract_rect(source: Rect2, cut: Rect2) -> Array[Rect2]:
	var overlap := source.intersection(cut)
	if not overlap.has_area(): return [source]
	var pieces: Array[Rect2] = []
	for rect in [Rect2(source.position.x,source.position.y,source.size.x,overlap.position.y-source.position.y),
		Rect2(source.position.x,overlap.end.y,source.size.x,source.end.y-overlap.end.y),
		Rect2(source.position.x,overlap.position.y,overlap.position.x-source.position.x,overlap.size.y),
		Rect2(overlap.end.x,overlap.position.y,source.end.x-overlap.end.x,overlap.size.y)]:
		if rect.has_area(): pieces.append(rect)
	return pieces
static func outline(rectangles: Array[Rect2]) -> Array[Dictionary]:
	# Split at all rectangle corners, then retain only occupied/empty transitions.
	var xs: Array[float] = []
	var ys: Array[float] = []
	for rect in rectangles:
		for x in [rect.position.x,rect.end.x]:
			if x not in xs: xs.append(x)
		for y in [rect.position.y,rect.end.y]:
			if y not in ys: ys.append(y)
	xs.sort(); ys.sort()
	var cells := {}
	for x in range(xs.size()-1):
		for y in range(ys.size()-1):
			var center := Vector2((xs[x]+xs[x+1])*.5,(ys[y]+ys[y+1])*.5)
			for rect in rectangles:
				if rect.has_point(center):
					cells[Vector2i(x,y)] = true
					break
	var edges: Array[Dictionary] = []
	for cell in cells:
		var x: int = cell.x
		var y: int = cell.y
		var rect := Rect2(xs[x],ys[y],xs[x+1]-xs[x],ys[y+1]-ys[y])
		for direction in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
			if cells.has(cell+direction): continue
			var band: Rect2
			match direction:
				Vector2i.UP: band = Rect2(rect.position,Vector2(rect.size.x,2))
				Vector2i.DOWN: band = Rect2(rect.position.x,rect.end.y-2,rect.size.x,2)
				Vector2i.LEFT: band = Rect2(rect.position,Vector2(2,rect.size.y))
				Vector2i.RIGHT: band = Rect2(rect.end.x-2,rect.position.y,2,rect.size.y)
			edges.append({"rect":band,"normal":Vector2(direction)})
	return edges
func draw_material(texture: Texture2D, target: Rect2, repeat: Vector2, tint: Color) -> void:
	if texture == null: return
	var start := (target.position/repeat).floor()
	var finish := (target.end/repeat).ceil()
	for x in range(int(start.x),int(finish.x)):
		for y in range(int(start.y),int(finish.y)):
			var origin := Vector2(x,y)*repeat
			var patch := target.intersection(Rect2(origin,repeat))
			var uv := Rect2((patch.position-origin)/repeat*texture.get_size(),patch.size/repeat*texture.get_size())
			draw_texture_rect_region(texture,patch,uv,tint)
func _draw() -> void:
	if theme == null: return
	for face in faces:
		draw_material(theme.wall_face,face,Vector2(theme.face_repeat,theme.face_repeat_y),Color(.82,.81,.76)*theme.wall_tint)
		# A wall end is a narrow return, not a compressed pillar image.
		for x in [face.position.x,face.end.x-4]:
			var side := Rect2(x,face.position.y,4,face.size.y)
			var neighbor := Vector2(x-1 if x == face.position.x else face.end.x+1,face.get_center().y)
			var covered := false
			for other in faces+tops:
				if other.has_point(neighbor): covered = true; break
			if not covered: draw_material(theme.wall_end,side,Vector2(theme.face_repeat,theme.face_repeat_y),Color(.76,.75,.71)*theme.wall_tint)
		draw_line(Vector2(face.position.x,face.end.y-1),face.end-Vector2(0,1),Color(0,0,0,.45),2)
	for top in tops:
		draw_material(theme.wall_top,top,Vector2(128,128),Color(.86,.86,.81)*theme.wall_tint)
		if theme.wall_top_wash.a > 0: draw_rect(top,theme.wall_top_wash)
	for edge in boundaries:
		draw_material(theme.wall_edge,edge.rect,Vector2(64,64),theme.wall_tint)
