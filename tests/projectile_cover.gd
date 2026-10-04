extends SceneTree
const Rooms = preload("res://scripts/world/authored_rooms.gd")
const Shot = preload("res://scenes/combat/projectile.tscn")
const Actor = preload("res://scenes/combat/player.tscn")
const Placement = preload("res://scripts/world/stage_placement.gd")
var game
func _initialize() -> void:
	call_deferred("run")
func shot(source, id: int, at: Vector2, options: Dictionary = {}):
	var bullet = Shot.instantiate()
	game.arena.get_node("Projectiles").add_child(bullet)
	options = options.duplicate()
	options.pos = at
	bullet.launch(source,0,id,0,options)
	return bullet
func run() -> void:
	game = load("res://scenes/game/exploration.tscn").instantiate()
	game.encounters_enabled = false
	root.add_child(game)
	game.set_physics_process(false)
	game.set_pause_reason("focus",false)
	var count := 0
	for id in Rooms.ORDER:
		var field = Rooms.make_room(id,["west","east"]).field
		for prop in field.placements:
			var original: Rect2 = prop.collision
			var cover: Rect2 = prop.projectile_rect()
			assert(prop.collision == original,"Projectile cover must not change movement")
			if original.has_area():
				count += 1
				assert(cover.encloses(original))
				assert(cover.has_point(Vector2(original.get_center().x,prop.visual_rect.get_center().y)),"Solid prop body must block shots: "+prop.placement_id)
			else: assert(not cover.has_area(),"Decorations must not become invisible walls")
	assert(count >= 185)
	var field = Rooms.make_room("colonnade",["west","east"]).field
	assert(game.switch_field(field).is_empty())
	var prop = field.placements.filter(func(p): return p.placement_id == "authored_column_330_580")[0]
	var middle: Vector2 = prop.position+prop.visual_rect.get_center()
	assert(not game.arena.solid(middle,1) and game.arena.projectile_solid(middle,1))
	assert(game.arena.projectile_line_blocked(middle-Vector2(60,0),middle+Vector2(60,0)))
	assert(game.arena.projectile_line_blocked(middle+Vector2(60,0),middle-Vector2(60,0)))
	assert(game.arena.projectile_line_blocked(middle,middle),"Zero-length ray inside cover")
	var enemy = Actor.instantiate()
	enemy.set_script(load("res://scripts/combat/fire_pouch_lizard.gd"))
	game.arena.get_node("Players").add_child(enemy)
	enemy.prepare(middle-Vector2(80,0))
	for local_y in [prop.collision.get_center().y,prop.visual_rect.get_center().y]:
		var origin: Vector2 = prop.position+Vector2(-60,local_y)
		var fire = shot(enemy,-1,origin,{"speed":900,"radius":7.8,"visual_variant":"enemy_fire_seed"})
		fire.step(.2,game.arena,[])
		assert(fire.state.life <= 0 and fire.position.x < prop.position.x,"Fireball cannot cross column at high speed")
		fire.queue_free()
	var hero = game.players[0]
	var normal = shot(hero,0,middle-Vector2(60,0))
	assert(normal.radius == 6)
	normal.step(.2,game.arena,[])
	assert(normal.state.life <= 0)
	normal.queue_free()
	var bounced = shot(hero,0,middle-Vector2(60,0),{"speed":500})
	bounced.state.bounce = 1
	bounced.step(.1,game.arena,[])
	assert(bounced.state.rebounds == 1 and bounced.state.velocity.x < 0)
	bounced.queue_free()
	var override_shot = shot(hero,0,middle-Vector2(60,0),{"radius":3})
	assert(override_shot.radius == 3,"Explicit fragment/enemy core radius is authoritative")
	override_shot.queue_free()
	# Grazing the enlarged player core hits, while a point just outside misses.
	for gap in [5.5,6.5]:
		enemy.state.pos = Vector2(650,460)
		enemy.state.hp = 10
		enemy.state.inv = 0
		var bullet = shot(hero,0,enemy.state.pos+Vector2(0,enemy.radius+gap),{"speed":0})
		bullet.step(0,game.arena,[enemy])
		assert((enemy.state.hp < 10) == (gap < 6))
		bullet.queue_free()
	# The firing offset cannot skip a 2px piece of cover.
	var thin := Placement.new()
	thin.position = Vector2(610,460)
	thin.collision = Rect2(-1,-20,2,40)
	thin.visual_rect = thin.collision
	game.arena.runtime_definition.placements.append(thin)
	hero.state.pos = Vector2(600,460)
	game.spawn_shot(0,0,0)
	assert(game.shots.back().state.life <= 0 and game.shots.back().state.pos.x < 610)
	game.queue_free()
	await process_frame
	print("PASS: 20-room cover audit, pillar base/body, high-speed fire, player grazing, ricochet and muzzle obstruction")
	quit()
