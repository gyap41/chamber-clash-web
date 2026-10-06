extends RefCounted
# 2026-10-06: physical height is independent of the span of the doorway.
# Existing stone/iron materials form fixed architecture; only the lattice moves.
const HEIGHT: float = 64.0
const TRAVEL: float = 70.0
const CASE_BOTTOM: float = 64.0
const CASE_TOP: float = 80.0
const IRON := Color("555951")
const IRON_TOP := Color("707267")
const EDGE := Color("252822")
const SILL = preload("res://assets/stages/ashen-foundry-v2/props/threshold.png")

# 2026-10-06: the upper structure is cut away on near/side walls, just as the
# room's coping is. Do not project an opaque overhead beam onto the whole exit.
class Passage extends Node2D:
	var direction := Vector2.UP
	var width: float = 144.0
	var theme: Resource
	var paint: Callable
	func _draw() -> void:
		paint.call(self,direction,width,theme)

static func draw_passage(canvas: Node2D, direction: Vector2, width: float, theme: Resource) -> void:
	if theme == null: return
	var half: float = width*.5
	var length: float = 86.0 if direction == Vector2.UP else 60.0
	var repeat_size: float = maxf(float(theme.floor_repeat),128.0)
	# World-aligned floor, progressively shaded into the connecting passage.
	for index in range(12):
		var distance: float = float(index)*length/12.0
		var band: Rect2
		if direction.x == 0:
			var y: float = -distance-length/12.0 if direction.y < 0 else distance
			band = Rect2(-half,y,width,length/12.0+.5)
		else:
			var x: float = -distance-length/12.0 if direction.x < 0 else distance
			band = Rect2(x,-half,length/12.0+.5,width)
		var shade: float = lerpf(.78,.12,float(index)/11.0)
		material(canvas,theme.floor_texture,band,Vector2.ONE*repeat_size,theme.floor_tint*Color(shade,shade,shade),Vector2.ZERO)
		if direction == Vector2.DOWN:
			# Continue both cut wall tops alongside the exit, so the floor does
			# not look like a rectangular carpet hanging into the exterior.
			for sign_value in [-1.0,1.0]:
				var x: float = -half-16 if sign_value < 0 else half
				var return_rect := Rect2(x,distance,16,length/12.0+.5)
				material(canvas,theme.wall_top,return_rect,Vector2(128,128),theme.wall_tint*Color(.86*shade,.86*shade,.81*shade),Vector2.ZERO)
				canvas.draw_line(return_rect.position,Vector2(return_rect.position.x,return_rect.end.y),Color(0,0,0,.5),1)
				canvas.draw_line(Vector2(return_rect.end.x,return_rect.position.y),return_rect.end,Color(0,0,0,.5),1)
	# Narrow inner returns belong to the passage, not a second freestanding frame.
	if direction == Vector2.UP:
		for sign_value in [-1.0,1.0]:
			var x: float = -half if sign_value < 0 else half-5
			material(canvas,theme.wall_end,Rect2(x,-length,5,length),Vector2(theme.face_repeat,theme.face_repeat_y),Color(.4,.4,.36),Vector2.ZERO)

static func draw_integrated(canvas: Node2D, direction: Vector2, width: float, closure: float, impact: float, texture: Texture2D, theme: Resource, origin: Vector2) -> void:
	var side: bool = direction.x != 0
	var north: bool = direction == Vector2.UP
	var half: float = width*.5
	var tangent: Vector2 = Vector2.DOWN if side else Vector2.RIGHT
	var rise: float = lift(closure,impact)
	# South is a cutaway through the near wall; retain the lower half of the grille.
	var cut_height: float = 32.0 if direction == Vector2.DOWN else HEIGHT
	canvas.draw_set_transform(origin,PI*.5 if side else 0.0)
	canvas.draw_texture_rect(SILL,Rect2(-half,-7,width,14),false,Color(.7,.7,.63))
	canvas.draw_set_transform(origin)
	for index in range(6):
		var socket_at: Vector2 = tangent*lerpf(-half+12,half-12,float(index)/5)
		canvas.draw_rect(Rect2(socket_at-Vector2(3,2),Vector2(6,4)),EDGE)
	# Small stone returns match the low wall rather than towering over it.
	for sign_value in [-1.0,1.0]:
		var at: Vector2 = tangent*(half+4)*sign_value
		box(canvas,Rect2(at-Vector2(8,9),Vector2(16,18)),0,8,Color("575848"),Color("73715b"),theme,origin)
		if north:
			box(canvas,Rect2(at-Vector2(6,5),Vector2(12,10)),8,HEIGHT,Color("575848"),Color("73715b"),theme,origin)
			canvas.draw_line(at+Vector2(-sign_value*4,-HEIGHT),at+Vector2(-sign_value*4,-8),EDGE,3)
			canvas.draw_line(at+Vector2(-sign_value*2,-HEIGHT),at+Vector2(-sign_value*2,-8),IRON_TOP,1)
		else:
			# Only the channel inside the wall is exposed above its cut surface.
			box(canvas,Rect2(at-Vector2(4,4),Vector2(8,8)),8,18,IRON,IRON_TOP)
	if rise < cut_height:
		if side:
			# A thick grate has two edges and transverse bars. Without the opaque
			# overhead casing its full length remains readable from above.
			for index in range(6):
				var y: float = lerpf(-half+10,half-10,float(index)/5)
				for x in [-9.0,6.0]:
					box(canvas,Rect2(x,y-3,3,6),rise,cut_height,IRON,IRON_TOP)
				# Thin ties connect both faces without filling the whole side
				# silhouette with overlapping opaque 18px-wide vertical faces.
				box(canvas,Rect2(-9,y-3,18,6),rise,minf(rise+3,cut_height),IRON,IRON_TOP)
			for x in [-9.0,6.0]:
				for z in [12.0,36.0]:
					if z+rise < cut_height:
						box(canvas,Rect2(x,-half,3,width),z+rise,minf(z+rise+4,cut_height),IRON,IRON_TOP)
		else:
			var visible_height: float = cut_height-rise
			var source := Rect2(0,texture.get_height()*(1.0-visible_height/HEIGHT),texture.get_width(),texture.get_height()*visible_height/HEIGHT)
			canvas.draw_texture_rect_region(texture,Rect2(-half,-cut_height,width,visible_height),source,Color(.72,.74,.67))
	if north:
		# North retains the lintel: the dark reveal behind it leads into the wall.
		box(canvas,Rect2(-half-8,-6,width+16,12),HEIGHT,CASE_TOP,Color("4b5045"),Color("6b6c57"),theme,origin)
		canvas.draw_line(Vector2(-half,-HEIGHT+6),Vector2(half,-HEIGHT+6),Color("1b201e"),3)
		for x in [-half+2,half-2]:
			canvas.draw_rect(Rect2(x-2,-CASE_TOP-4,4,14),IRON)
			canvas.draw_circle(Vector2(x,-CASE_TOP+2),1.3,Color("928267"))
	canvas.draw_set_transform(Vector2.ZERO)

static func lift(closure: float, impact: float = 0.0) -> float:
	return (1.0-closure*closure)*TRAVEL+sin(clampf(impact/.16,0.0,1.0)*PI)*2.0

static func mount(direction: Vector2) -> Vector2:
	# North opening center is inside a 48px wall; seat on its inner return.
	return Vector2(0,24) if direction == Vector2.UP else Vector2.ZERO

static func draw(canvas: Node2D, direction: Vector2, width: float, closure: float, impact: float, texture: Texture2D, theme: Resource, origin: Vector2 = Vector2.ZERO) -> void:
	var side: bool = direction.x != 0
	var tangent: Vector2 = Vector2.DOWN if side else Vector2.RIGHT
	var half: float = width*.5
	var rise: float = lift(closure,impact)
	canvas.draw_set_transform(origin)
	# The sill is flush with the floor; recessed sockets show where each bar lands.
	var sill: Rect2 = Rect2(-12,-half,24,width) if side else Rect2(-half,-10,width,20)
	canvas.draw_set_transform(origin,PI*.5 if side else 0.0)
	canvas.draw_texture_rect(SILL,Rect2(-half,-10,width,20),false,Color(.8,.8,.73))
	canvas.draw_set_transform(origin)
	canvas.draw_rect(sill,Color(0,0,0,.25),false,1.0)
	for index in range(6):
		var at: Vector2 = tangent*lerpf(-half+12,half-12,float(index)/5)
		var socket: Vector2 = Vector2(7,5) if side else Vector2(6,4)
		canvas.draw_rect(Rect2(at-socket*.5,socket),Color("252923"))
	# Back lips of the two guide channels, then the moving lattice.
	for sign_value in [-1.0,1.0]:
		var at: Vector2 = tangent*(half+2)*sign_value
		box(canvas,Rect2(at-Vector2(7,10),Vector2(14,20)),0,CASE_BOTTOM,Color("343a33"),Color("44483e"))
	if rise < HEIGHT:
		if side:
			# Same 3D bars as the north gate, projected along the N/S floor axis.
			# Clip each bar at the *height* of the casing, not at an image edge.
			for index in range(6):
				var y: float = lerpf(-half+12,half-12,float(index)/5)
				box(canvas,Rect2(-4,y-3,8,6),rise,HEIGHT,IRON,IRON_TOP)
			for z in [15.0,38.0]:
				if z+rise < HEIGHT:
					box(canvas,Rect2(-5,-half,10,width),z+rise,minf(z+rise+5,HEIGHT),IRON,IRON_TOP)
		else:
			var visible: float = (HEIGHT-rise)/HEIGHT
			var target := Rect2(-half,-HEIGHT,width,HEIGHT-rise)
			var source := Rect2(0,texture.get_height()*(1.0-visible),texture.get_width(),texture.get_height()*visible)
			canvas.draw_texture_rect_region(texture,target,source,Color(.69,.72,.63))
	# Guide lips obscure both edges of the moving panel, anchored into wall returns.
	for sign_value in [-1.0,1.0]:
		var at: Vector2 = tangent*(half+2)*sign_value
		box(canvas,Rect2(at-Vector2(9,12),Vector2(18,24)),0,7,Color("575848"),Color("73715b"),theme,origin)
		if side:
			# A U-channel, not a solid post painted over the edge-on moving bars.
			for lip in [-8.0,5.0]:
				box(canvas,Rect2(at.x+lip,at.y-5,3,10),7,CASE_BOTTOM+3,IRON,IRON_TOP)
		else:
			box(canvas,Rect2(at.x-5,at.y,10,8),7,CASE_BOTTOM+3,IRON,IRON_TOP)
			canvas.draw_line(at+Vector2(-2,-CASE_BOTTOM+6),at+Vector2(-2,-8),EDGE,2.0)
		for z in [12.0,46.0]:
			canvas.draw_circle(at+Vector2(2,-z),1.6,Color("8b805b"))
	# A deep lintel rests on the guides and overlaps the existing wall at both ends.
	# Its underside occludes raised bars; the top and front are separate materials.
	var casing: Rect2 = Rect2(-12,-half-11,24,width+22) if side else Rect2(-half-11,-8,width+22,16)
	box(canvas,casing,CASE_BOTTOM,CASE_TOP,Color("4b5045"),Color("6b6c57"),theme,origin)
	if side:
		canvas.draw_line(Vector2(-7,-half-CASE_TOP+1),Vector2(-7,half-CASE_TOP-1),EDGE,3.0)
		canvas.draw_line(Vector2(7,-half-CASE_TOP+1),Vector2(7,half-CASE_TOP-1),Color("87816a"),1.0)
	else:
		canvas.draw_rect(Rect2(-half,-CASE_TOP+5,width,6),EDGE)
		canvas.draw_line(Vector2(-half,8-CASE_BOTTOM),Vector2(half,8-CASE_BOTTOM),Color("272b25"),3)
	# End straps visibly tie the casing into both wall returns, not a floating bar.
	for sign_value in [-1.0,1.0]:
		var at: Vector2 = tangent*(half-1)*sign_value
		var strap: Rect2 = Rect2(-13,at.y-3-CASE_TOP,26,6) if side else Rect2(at.x-3,-8-CASE_TOP,6,16)
		canvas.draw_rect(strap,Color("3e433b"))
		canvas.draw_circle(strap.get_center(),1.6,Color("928267"))
	canvas.draw_set_transform(Vector2.ZERO)

static func box(canvas: Node2D, footprint: Rect2, low: float, high: float, face: Color, top: Color, theme: Resource = null, origin: Vector2 = Vector2.ZERO) -> void:
	var front := Rect2(footprint.position.x,footprint.end.y-high,footprint.size.x,high-low)
	var cap := Rect2(footprint.position-Vector2(0,high),footprint.size)
	canvas.draw_rect(front,face)
	if theme != null: material(canvas,theme.wall_face,front,Vector2(theme.face_repeat,theme.face_repeat_y),Color(.82,.81,.76)*theme.wall_tint,origin)
	canvas.draw_rect(cap,top)
	if theme != null: material(canvas,theme.wall_top,cap,Vector2(128,128),Color(.86,.86,.81)*theme.wall_tint,origin)
	canvas.draw_rect(front,EDGE,false,1)
	canvas.draw_rect(cap,EDGE,false,1)
	canvas.draw_line(cap.position+Vector2(1,1),Vector2(cap.end.x-1,cap.position.y+1),top.lightened(.12),1)

static func material(canvas: Node2D, texture: Texture2D, rect: Rect2, repeat: Vector2, tint: Color, origin: Vector2) -> void:
	if texture == null:
		canvas.draw_rect(rect,tint)
		return
	# Preserve the wall's world-space texture scale instead of stretching a stone patch.
	var world_rect := Rect2(rect.position+canvas.global_position+origin,rect.size)
	var start: Vector2 = (world_rect.position/repeat).floor()
	var finish: Vector2 = (world_rect.end/repeat).ceil()
	for x in range(int(start.x),int(finish.x)):
		for y in range(int(start.y),int(finish.y)):
			var tile := Vector2(x,y)*repeat
			var patch: Rect2 = world_rect.intersection(Rect2(tile,repeat))
			var source := Rect2((patch.position-tile)/repeat*texture.get_size(),patch.size/repeat*texture.get_size())
			canvas.draw_texture_rect_region(texture,Rect2(patch.position-canvas.global_position-origin,patch.size),source,tint)
