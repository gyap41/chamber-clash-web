extends SceneTree
const Index = preload("res://tools/visual_hub/asset_index.gd")
const Registry = preload("res://tools/visual_hub/preview_registry.gd")
const Store = preload("res://tools/visual_hub/conditions.gd")
const Rig = preload("res://scripts/visuals/root_runner_rig.gd")
func _initialize(): call_deferred("run")
func run():
	var rig = Rig.new()
	root.add_child(rig)
	var supported := 0
	for i in range(240):
		var before: Array = rig.feet.duplicate(true)
		rig.advance(1.0/120,Rig.F*72.0/120,{"phase":"chase"})
		for n in range(6):
			if not before[n].swing and not rig.feet[n].swing:
				assert(before[n].pos.distance_to(rig.feet[n].pos)<.001,"Planted foot slipped")
				supported += 1
	assert(supported>100)
	for i in range(60): rig.advance(1.0/120,Vector2.ZERO,{"phase":"grace"})
	var stopped: Array = rig.feet.duplicate(true)
	for i in range(60): rig.advance(1.0/120,Vector2.ZERO,{"phase":"grace"})
	for i in range(6): assert(stopped[i].pos.distance_to(rig.feet[i].pos)<.001 and not rig.feet[i].swing)
	# Rapid stop/resume used to jump to the global gait phase mid-swing.
	for dt in [1.0/60,1.0/120]:
		rig.reset_pose()
		for n in range(600):
			var moving: bool = n%31<24
			var before: Array = rig.feet.duplicate(true)
			var knees: Array[Vector2] = []
			for j in range(6): knees.append(rig.leg_points(j)[1])
			rig.advance(dt,Rig.F*72*dt if moving else Vector2.ZERO,{"phase":"chase" if moving else "grace"})
			for j in range(6):
				assert(before[j].pos.distance_to(rig.feet[j].pos)<400*dt,"Foot jump dt=%s tick=%s foot=%s delta=%s prev=%s next=%s"%[dt,n,j,before[j].pos.distance_to(rig.feet[j].pos),before[j],rig.feet[j]])
				assert(knees[j].distance_to(rig.leg_points(j)[1])<300*dt,"Knee snaps around the body")
				if not before[j].swing and not rig.feet[j].swing:
					assert(before[j].pos.distance_to(rig.feet[j].pos)<.001)
	# Stop during maximum lift: preserve height and settle instead of dropping in one frame.
	rig.reset_pose()
	for n in range(60):
		rig.advance(1.0/60,Rig.F*72/60,{"phase":"chase"})
		if rig.feet[1].lift>1.7: break
	var raised: float = rig.feet[1].lift
	rig.advance(1.0/60,Vector2.ZERO,{"phase":"grace"})
	assert(raised>1.7 and rig.feet[1].lift>1.0 and rig.feet[1].lift<raised)
	for n in range(20): rig.advance(1.0/60,Vector2.ZERO,{"phase":"grace"})
	assert(rig.feet[1].lift==0 and rig.body_offset==Vector2.ZERO)
	rig.queue_free()
	var index = Index.new(); index.reload()
	var item = index.detail("enemy:root_runner_prototype")
	assert(item.game and item.preview)
	for dt in [1.0/60,1.0/120]:
		var settings = Store.defaults();settings.action="攻撃"
		var adapter = Registry.new().create_preview(root,item,settings)
		var hits := 0
		var before_damage := 0.0
		for n in range(int(8.0/dt)):
			adapter.advance(dt)
			var actor = adapter.players[0]
			if adapter.damage_total > before_damage:
				assert(actor.attack_phase=="recover")
				var pose = Rig.attack_pose(actor.enemy_visual_snapshot())
				assert(pose.curl==1 and actor.dash_hit and actor.stop_reason=="contact","Contact must occur while curled")
				hits += 1
			before_damage=adapter.damage_total
		assert(hits>=3,"Need three real tackle cycles")
		adapter.finish();adapter.free()
	# A locked direction never chases a sidestepping target; misses finish within 420px.
	for dt in [1.0/60,1.0/120,.1]:
		var settings = Store.defaults();settings.action="攻撃"
		var adapter = Registry.new().create_preview(root,item,settings)
		var actor = adapter.players[0]
		for n in range(500):
			adapter.advance(dt)
			if actor.attack_phase=="windup": break
		assert(actor.attack_phase=="windup")
		var open_field=adapter.arena.definition.duplicate(true)
		open_field.field_rect=Rect2(0,0,1600,1000)
		open_field.fighter_bounds=Rect2(30,30,1540,940)
		assert(adapter.arena.configure_field(open_field,0).is_empty())
		var locked: float = actor.attack_angle
		var start: Vector2 = actor.state.pos
		adapter.target_position += Rig.S*100
		adapter.players[1].state.pos = adapter.target_position
		for n in range(200):
			adapter.advance(dt)
			if actor.attack_phase=="recover": break
		assert(actor.attack_phase=="recover" and actor.stop_reason=="miss")
		assert(adapter.damage_total==0 and absf(actor.attack_angle-locked)<.0001)
		assert(absf(actor.state.pos.distance_to(start)-420)<.01,"Dash must stop at fixed range")
		assert(absf((actor.state.pos-start).dot(Rig.S))<.01,"Dash homed after locking")
		for n in range(int(.6/dt)): adapter.advance(dt)
		assert(Rig.attack_pose(actor.enemy_visual_snapshot()).curl==0,"Recovery must unfold")
		adapter.finish();adapter.free()
	# Thin physical wall must stop a long step, including contact damage behind it.
	var wall_settings = Store.defaults();wall_settings.action="攻撃"
	var wall_adapter = Registry.new().create_preview(root,item,wall_settings)
	var wall_actor = wall_adapter.players[0]
	var wall_start: Vector2 = wall_actor.state.pos
	var wall_field = wall_adapter.arena.definition.duplicate(true)
	wall_field.walls.append(Rect2(wall_start+Vector2(35,-70),Vector2(3,180)))
	assert(wall_adapter.arena.configure_field(wall_field,0).is_empty())
	wall_actor.attack_phase="dash";wall_actor.attack_angle=0
	wall_adapter.target_position=wall_start+Vector2(65,0)
	wall_adapter.players[1].state.pos=wall_adapter.target_position
	wall_adapter.advance(.25)
	assert(wall_actor.bounce_count==1 and wall_actor.attack_phase=="dash")
	assert(cos(wall_actor.attack_angle)<-.99,"Vertical wall must reverse horizontal velocity")
	assert(wall_actor.state.pos.x<wall_start.x+18 and wall_adapter.damage_total==0)
	wall_adapter.finish();wall_adapter.free()
	# Oblique incidence preserves its tangential component and does not retarget.
	for dt in [1.0/60,1.0/120,.1]:
		var settings=Store.defaults();settings.action="攻撃";settings.scenario="wall"
		var preview=Registry.new().create_preview(root,item,settings)
		var actor=preview.players[0]
		for n in range(300):
			preview.advance(dt)
			if actor.bounce_count==1: break
		var reflected := Vector2.from_angle(actor.attack_angle)
		assert(reflected.x<-.7 and reflected.y>.7,"Diagonal wall reflection must preserve tangent")
		assert(actor.bounce_count==1)
		for n in range(100):
			preview.advance(dt)
			if actor.attack_phase=="recover": break
		assert(actor.attack_phase=="recover" and actor.stop_reason=="contact")
		assert(is_equal_approx(preview.damage_total,.7),"Reflected attack must hit once")
		preview.finish();preview.free()
	# One contact per attack, even after target invulnerability expires during recovery.
	var hit_settings = Store.defaults();hit_settings.action="攻撃"
	var hit_adapter = Registry.new().create_preview(root,item,hit_settings)
	for n in range(500):
		hit_adapter.advance(1.0/60)
		if hit_adapter.damage_total>0: break
	var contact_position: Vector2 = hit_adapter.players[0].state.pos
	var damage: float = hit_adapter.damage_total
	assert(is_equal_approx(damage,.7))
	for n in range(30): hit_adapter.advance(1.0/60)
	assert(is_equal_approx(hit_adapter.damage_total,damage))
	assert(absf(contact_position.distance_to(hit_adapter.players[0].state.pos)-40)<.01,"Contact must restore tackle spacing")
	# Rebound must respect an obstacle behind the actor and still finish recovery.
	var rebound_actor = hit_adapter.players[0]
	var rebound_start: Vector2 = rebound_actor.state.pos
	rebound_actor.attack_angle=0
	rebound_actor.recover_tackle("contact")
	var rebound_field=hit_adapter.arena.definition.duplicate(true)
	rebound_field.walls.append(Rect2(rebound_start+Vector2(-30,-50),Vector2(3,100)))
	assert(hit_adapter.arena.configure_field(rebound_field,0).is_empty())
	hit_adapter.advance(.25)
	assert(rebound_actor.state.pos.x>=rebound_start.x-9.1 and rebound_actor.state.pos.x<rebound_start.x)
	assert(not hit_adapter.arena.solid(rebound_actor.state.pos,rebound_actor.radius))
	hit_adapter.advance(.7)
	assert(rebound_actor.attack_phase=="chase")
	hit_adapter.finish();hit_adapter.free()
	# Arena boundary blocks the charge even at a long frame; recovery does not get stuck.
	var settings = Store.defaults();settings.action="攻撃"
	var adapter = Registry.new().create_preview(root,item,settings)
	var actor = adapter.players[0]
	actor.attack_phase="dash";actor.attack_angle=Rig.F.angle()
	var start: Vector2 = actor.state.pos
	adapter.arena.fighter_bounds=Rect2(start-Vector2(100,100),Vector2(130,130))
	adapter.advance(1.0)
	assert(actor.attack_phase=="recover" and actor.stop_reason=="wall")
	assert(actor.bounce_count==1 and actor.dash_travel<420 and adapter.damage_total==0)
	actor.state.hp=0
	var dead_position: Vector2 = actor.state.pos
	adapter.advance(.5)
	assert(actor.state.pos==dead_position and adapter.damage_total==0,"Dead actor must not charge")
	actor.prepare(start)
	assert(actor.dash_travel==0 and actor.bounce_count==0 and not actor.dash_hit and actor.attack_phase=="grace")
	adapter.finish();adapter.free()
	print("PASS: planted feet and stop; 60/120Hz contact tackles; locked miss/range at 60/120/10Hz; thin wall/boundary stop, one hit, unfold, death and reset")
	quit()
