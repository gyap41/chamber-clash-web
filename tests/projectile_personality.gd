extends SceneTree
class EmptyArena:
	var projectile_bounds := Rect2(-10000,-10000,20000,20000)
	func solid(_pos: Vector2, _radius: float) -> bool: return false
	func line_blocked(_a: Vector2, _b: Vector2) -> bool: return false
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var game = load("res://scenes/game/main.tscn").instantiate();root.add_child(game)
	game.set_physics_process(false)
	preload("res://tests/helpers/battle.gd").passive_opponents(game)
	preload("res://tests/helpers/battle.gd").start(game,0)
	var p = game.players[0];var q = game.players[1]
	var arena = EmptyArena.new()
	# An enlarged core catches a grazing target that a normal round misses.
	for id in [0,13]:
		q.state.pos=Vector2(500,500);q.state.hp=10;q.state.invuln=0
		game.spawn_shot(0,id,0,{"pos":q.state.pos+Vector2(0,q.radius+8),"speed":0})
		var b = game.shots.back();b.step(0.0,arena,q)
		assert((q.state.hp<10)==(id==13))
	# Heavy cores grow collision and art together, cap at 60%, and never grow derived shots.
	p.relics = []
	game.spawn_shot(0,0,0,{})
	var base_radius: float = game.shots.back().radius
	var base_art: Vector2 = game.shots.back().get_node("Art").base_scale
	game.spawn_shot(0,0,0,{"depth":1})
	var derived_art: Vector2 = game.shots.back().get_node("Art").base_scale
	for count in [1,2,8]:
		p.relics.clear()
		for copy in range(count): p.relics.append(6)
		game.spawn_shot(0,0,0,{})
		var size_factor := 1.0+minf(.6,.12*count)
		assert(is_equal_approx(game.shots.back().radius,base_radius*size_factor))
		assert(game.shots.back().get_node("Art").base_scale.is_equal_approx(base_art*size_factor))
		game.spawn_shot(0,0,0,{"depth":1})
		assert(is_equal_approx(game.shots.back().radius,base_radius))
		assert(game.shots.back().get_node("Art").base_scale.is_equal_approx(derived_art))
	p.relics = []
	# Explicit fragment radius wins, even when sourced from a large weapon.
	game.spawn_shot(0,9,0,{"radius":3,"visual_variant":"comet_shard","depth":1})
	var fragment = game.shots.back()
	assert(fragment.radius==3 and fragment.get_node("Art").profile.thruster==0)
	game.spawn_shot(0,17,0,{"parcel":true})
	var parcel = game.shots.back();assert(is_equal_approx(parcel.radius,16.8))
	game.spawn_shot(0,17,0)
	assert(game.shots.back().radius==6)
	assert(parcel.get_node("Art").texture.get_size().length()*parcel.get_node("Art").scale.x>game.shots.back().get_node("Art").texture.get_size().length()*game.shots.back().get_node("Art").scale.x*2)
	# Bubble acceleration changes the artwork, not its contact radius.
	game.spawn_shot(0,13,0)
	var bubble = game.shots.back();var art=bubble.get_node("Art")
	art.refresh(.1,Vector2.RIGHT*60);var before:Vector2=art.scale
	art.refresh(1.1,Vector2.RIGHT*480)
	assert(art.scale.x/art.scale.y>before.x/before.y and bubble.radius==12)
	# Long laser afterglow is visual only; trails have a bounded sample budget.
	game.spawn_shot(0,6,0);var laser=game.shots.back();art=laser.get_node("Art")
	assert(is_equal_approx(laser.radius,4.8) and art.texture.get_width()*art.scale.x>=40)
	for i in range(100): art.position.x+=10;art.refresh(i*.02,Vector2.RIGHT*950)
	assert(art.samples.size()<=24)
	# Enemy presentation must not enlarge collision, nor affect player/duel shots.
	for variant in ["enemy_fire_seed","enemy_quill","boss_rivet","boss_shell","boss_cannon",""]:
		p.team_id = "players"
		game.spawn_shot(0,0,0,{"radius":6,"visual_variant":variant})
		var normal = game.shots.back()
		var baseline: Vector2 = normal.get_node("Art").scale
		p.team_id = "enemies"
		game.spawn_shot(0,0,0,{"radius":6,"visual_variant":variant})
		var enemy_shot = game.shots.back()
		enemy_shot.get_node("Art").refresh(.4,Vector2.RIGHT*420)
		assert(enemy_shot.radius == normal.radius and enemy_shot.damage == normal.damage)
		assert(enemy_shot.state.velocity == normal.state.velocity)
		assert(enemy_shot.get_node("Art").scale.is_equal_approx(baseline*(1.0 if variant == "boss_cannon" else 1.3)))
	p.team_id = "players"
	print("PASS: projectile grazing contact, radius overrides, parcel contrast, bubble launch and bounded laser wake")
	game.queue_free();quit()
