extends Node2D
# Inspection overlays only. Artwork and collision simulation belong to the game.
var adapter
func _draw() -> void:
	if adapter == null or adapter.conditions.is_empty(): return
	var c: Dictionary = adapter.conditions
	var arena = adapter.arena
	if arena != null and adapter.record.method == "stage":
		if c.movement_bounds: draw_rect(arena.fighter_bounds,Color("77f2b9"),false,2)
		if c.bullet_bounds: draw_rect(arena.projectile_bounds,Color("ffc477"),false,2)
		if c.spawns:
			for point in arena.runtime_definition.spawns:
				draw_circle(point,12,Color("70dfff"),false,3)
		if c.supplies:
			var n := 0
			for group in arena.runtime_definition.supply_points:
				var color := Color.from_hsv(float(n)/maxi(1,arena.runtime_definition.supply_points.size()),.6,1)
				for point in arena.runtime_definition.supply_points[group]:
					draw_arc(point,17+n*4,0,TAU,40,color,2)
					draw_string(ThemeDB.fallback_font,point+Vector2(20,n*13),group,HORIZONTAL_ALIGNMENT_LEFT,-1,12,color)
				n += 1
	if c.guides and not adapter.players.is_empty():
		var p = adapter.players[0]
		draw_circle(p.position,p.radius,Color("77f2b9"),false,1)
		if p.has_weapon():
			var sprite: Sprite2D = p.get_node("Weapon/Sprite")
			var body: Dictionary = p.Weapons.Visuals.profile(p.weapon().id).get("body",{})
			if body.has("grip"):
				var local: Vector2 = (p.Weapons.Visuals.vec(body.grip)-Vector2.ONE*.5)*sprite.texture.get_size()*Vector2(1,-1 if sprite.flip_v else 1)
				var point: Vector2 = to_local(sprite.to_global(local))
				draw_circle(point,3,Color("69ffba"))
			draw_circle(p.presentation_muzzle(p.weapon().id,p.state.angle),3,Color("ffad59"))
		for shot in adapter.shots:
			draw_circle(shot.state.pos,float(shot.radius),Color("ffb566"),false,1)
func _process(_dt: float) -> void: queue_redraw()
