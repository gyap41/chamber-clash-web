extends Node2D
# Presentation only; the field definition remains the authority for geometry.
func _draw() -> void:
	var arena = get_parent().get_parent()
	if arena.runtime_definition == null or arena.runtime_definition.theme == null: return
	var theme = arena.runtime_definition.theme
	var floor_texture: Texture2D = theme.floor_texture
	var foundation_texture: Texture2D = theme.foundation
	if floor_texture == null: return
	var regions = arena.runtime_definition.floor_regions
	if regions.is_empty():
		draw_texture_rect(floor_texture,arena.field_rect,false,Color(.83,.86,.86))
		return
	# Keep a consistent texture scale across the room and its connecting passage.
	draw_rect(arena.field_rect,theme.exterior_color)
	# A subdued masonry foundation fades into the void. It is not walkable floor.
	for index in range(arena.runtime_definition.walls.size()):
		if not arena.runtime_definition.wall_textures.has(index) and (arena.runtime_definition.wall_ids.is_empty() or arena.runtime_definition.wall_materials.get(arena.runtime_definition.wall_ids[index],"cover") == "cover"): continue
		var wall: Rect2 = arena.runtime_definition.walls[index]
		for margin in range(28,3,-2):
			draw_rect(wall.grow(margin).intersection(arena.field_rect),Color(.12,.15,.16,.035))
		if foundation_texture == null: continue
		var foundation := wall.grow(7).intersection(arena.field_rect)
		for x in range(int(foundation.position.x),int(foundation.end.x),48):
			for y in range(int(foundation.position.y),int(foundation.end.y),48):
				var extent := Vector2(minf(48,foundation.end.x-x),minf(48,foundation.end.y-y))
				draw_texture_rect_region(foundation_texture,Rect2(Vector2(x,y),extent),Rect2(Vector2.ZERO,extent/48*foundation_texture.get_size()),Color(.18,.22,.23))
	for region in regions:
		if theme.floor_repeat == 0:
			var source := Rect2((region.position-arena.field_rect.position)/arena.field_rect.size*floor_texture.get_size(),region.size/arena.field_rect.size*floor_texture.get_size())
			draw_texture_rect_region(floor_texture,region,source,theme.floor_tint)
		else:
			var step: int = theme.floor_repeat
			for x in range(int(floor(region.position.x/step))*step,int(ceil(region.end.x)),step):
				for y in range(int(floor(region.position.y/step))*step,int(ceil(region.end.y)),step):
					var tile := Rect2(x,y,step,step).intersection(region)
					var source := Rect2((tile.position-Vector2(x,y))/step*floor_texture.get_size(),tile.size/step*floor_texture.get_size())
					var variation := 1.0
					if theme.floor_wash.a > 0: variation = .96+float(posmod(x/step*17+y/step*31,5))*.02
					draw_texture_rect_region(floor_texture,tile,source,theme.floor_tint*Color(variation,variation,variation,1))
		if theme.floor_wash.a > 0: draw_rect(region,theme.floor_wash)
	for placement in arena.runtime_definition.placements:
		if placement.floor_motif == 1:
			draw_casting_bed(Rect2(placement.position+placement.visual_rect.position,placement.visual_rect.size))
		if placement.floor_decal and placement.texture != null:
			var patch := Rect2(placement.position+placement.visual_rect.position,placement.visual_rect.size)
			for region in regions:
				var clipped := patch.intersection(region)
				if not clipped.has_area(): continue
				var source := Rect2((clipped.position-patch.position)/patch.size*placement.texture.get_size(),clipped.size/patch.size*placement.texture.get_size())
				draw_texture_rect_region(placement.texture,clipped,source,placement.tint)
		var rect: Rect2 = placement.visual_rect
		var foot: Vector2 = placement.position+Vector2(rect.get_center().x,rect.end.y)
		if placement.wall_shadow:
			for i in range(8,0,-1):
				var patch := Rect2(placement.position.x-rect.size.x*.5-i,placement.position.y,rect.size.x+2*i,18+i*2)
				for region in regions:
					var clipped := patch.intersection(region)
					if clipped.has_area(): draw_rect(clipped,Color(0,0,0,.045))
		if placement.floor_mark == 1:
			for i in range(12,0,-1):
				draw_set_transform(foot+Vector2(6,8),0,Vector2(20+i*4,5+i*1.5))
				draw_circle(Vector2.ZERO,1,Color(.035,.025,.02,.032))
			draw_set_transform(Vector2.ZERO)
		elif placement.floor_mark == 2:
			for i in range(17):
				var start := foot+Vector2(-55+posmod(i*37,112),7+posmod(i*13,26))
				draw_line(start,start+Vector2(5+posmod(i*11,18),-2),Color(.53,.47,.35,.13),1)
	# Contact shadows anchor the masonry to the floor, without changing collisions.
	for index in range(arena.runtime_definition.walls.size()):
		if not arena.runtime_definition.wall_textures.has(index) and (arena.runtime_definition.wall_ids.is_empty() or arena.runtime_definition.wall_materials.get(arena.runtime_definition.wall_ids[index],"cover") == "cover"): continue
		var wall: Rect2 = arena.runtime_definition.walls[index]
		for region in regions:
			var shadow := Rect2(wall.position+Vector2(5,7),wall.size+Vector2(5,5)).intersection(region)
			if shadow.has_area(): draw_rect(shadow,Color(0,0,0,.28))
			if theme.shadow_length > 0:
				for step in range(6):
					var distance: float = theme.shadow_length*(1.0-step/6.0)
					var shade := Rect2(wall.position+Vector2(5,8),wall.size+Vector2(8,distance)).intersection(region)
					if shade.has_area(): draw_rect(shade,Color(0,0,0,.045))
	# Draw shadows on the floor, never on top of a sorted actor or furnishing.
	for placement in arena.runtime_definition.placements:
		if not placement.contact_shadow: continue
		if placement.shadow_rect.has_area():
			var patch := Rect2(placement.position+placement.shadow_rect.position,placement.shadow_rect.size)
			# Tight feathered footprint, not a detached cast-shadow polygon.
			for spread in [2.0,1.0,0.0]:
				var ellipse := PackedVector2Array()
				for i in range(24):
					ellipse.append(patch.get_center()+Vector2(cos(i*TAU/24),sin(i*TAU/24))*(patch.size*.5+Vector2.ONE*spread))
				for region in regions:
					var clip := PackedVector2Array([region.position,Vector2(region.end.x,region.position.y),region.end,Vector2(region.position.x,region.end.y)])
					for part in Geometry2D.intersect_polygons(ellipse,clip): draw_colored_polygon(part,Color(0,0,0,.12))
			continue
		var rect: Rect2 = placement.visual_rect
		var foot: Vector2 = placement.position+Vector2(rect.get_center().x,rect.end.y-3)
		var half := rect.size.x*.43
		var reach := Vector2(rect.size.y*.17,rect.size.y*.13)
		if theme.shadow_length > 0:
			var polygon := PackedVector2Array([foot+Vector2(-half,-9),foot+Vector2(half,-9),foot+Vector2(half,3)+reach,foot+Vector2(-half,3)+reach])
			for region in regions:
				var clip := PackedVector2Array([region.position,Vector2(region.end.x,region.position.y),region.end,Vector2(region.position.x,region.end.y)])
				for part in Geometry2D.intersect_polygons(polygon,clip): draw_colored_polygon(part,Color(0,0,0,.20))
		draw_set_transform(foot,0,Vector2(half,7))
		draw_circle(Vector2.ZERO,1,Color(0,0,0,.30))
		draw_set_transform(Vector2.ZERO)

# Flush old machinery footprint; authored wholly inside a floor region.
func draw_casting_bed(rect: Rect2) -> void:
	draw_rect(rect,Color(.08,.085,.075,.19))
	for inset in [0.0,12.0]:
		draw_rect(rect.grow(-inset),Color(.12,.13,.115,.5),false,2)
	for side in [rect.position.x+18,rect.end.x-18]:
		for y in range(int(rect.position.y+24),int(rect.end.y-12),64):
			draw_circle(Vector2(side,y),2.5,Color(.09,.10,.09,.6))
			draw_arc(Vector2(side,y),2.5,PI,TAU,6,Color(.46,.43,.34,.3),1)
	for x in range(int(rect.position.x+96),int(rect.end.x-32),96):
		draw_line(Vector2(x,rect.position.y+14),Vector2(x,rect.end.y-14),Color(.1,.11,.10,.2),1)
