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
		var source := Rect2((region.position-arena.field_rect.position)/arena.field_rect.size*floor_texture.get_size(),region.size/arena.field_rect.size*floor_texture.get_size())
		draw_texture_rect_region(floor_texture,region,source,theme.floor_tint)
	# Contact shadows anchor the masonry to the floor, without changing collisions.
	for index in range(arena.runtime_definition.walls.size()):
		if not arena.runtime_definition.wall_textures.has(index) and (arena.runtime_definition.wall_ids.is_empty() or arena.runtime_definition.wall_materials.get(arena.runtime_definition.wall_ids[index],"cover") == "cover"): continue
		var wall: Rect2 = arena.runtime_definition.walls[index]
		for region in regions:
			var shadow := Rect2(wall.position+Vector2(5,7),wall.size+Vector2(5,5)).intersection(region)
			if shadow.has_area(): draw_rect(shadow,Color(0,0,0,.28))
