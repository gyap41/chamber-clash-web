extends "res://tools/visual_hub/preview_adapter.gd"
# Isolated real enemy AI/projectile simulation; no main-game room or saved progress.
func is_beetle() -> bool:
	return record.get("definition",{}).get("id","") == "root_runner_prototype"
func facing() -> Vector2:
	return Vector2(1,1).normalized() if is_beetle() else direction(int(conditions.aim))
func initialize(item: Dictionary, settings: Dictionary) -> void:
	record = item.duplicate(true)
	conditions = settings.duplicate(true)
	seed_value = int(settings.seed)
	seed(seed_value)
	var field = load("res://data/fields/duel.tres").duplicate(true)
	field.walls.clear()
	_setup_arena(field)
	if arena == null: return
	arena.z_index = 30 # Keep the adapter backdrop behind negative-depth floor layers.
	source_position = Vector2(560,300)
	var script = load(record.definition.script)
	var actor = PlayerScene.instantiate()
	actor.set_script(script)
	arena.get_node("Players").add_child(actor)
	actor.prepare(source_position)
	var distance := 300.0 if is_beetle() else (40.0 if float(actor.spec.range) < 100 else 180.0)
	target_position = source_position+facing()*distance
	var target = PlayerScene.instantiate()
	arena.get_node("Players").add_child(target)
	if is_beetle(): target.set_character(0)
	target.reset(target_position)
	players = [actor,target]
	roster.configure([{"id":"enemy-preview","team":"enemies","controller":"external"},{"id":"target","team":"player","controller":"external"}])
	session = Session.new(self)
	for i in range(2):
		players[i].battle_roster = roster
		players[i].battle_slot = i
		players[i].combat_service = weakref(session)
		players[i].weapon_event_requested.connect(presentation.weapon_event)
		players[i].burst_requested.connect(presentation.burst)
		players[i].ring_requested.connect(presentation.ring)
		players[i].state.angle = facing().angle()
		players[i].sync_visual()
	target.visible = conditions.action == "攻撃"
	bounds = Rect2(180,0,760,600) if conditions.action == "攻撃" else Rect2(source_position-Vector2(64,80),Vector2(128,112))
	if conditions.action == "攻撃" and actor.spec.range < 100: bounds = Rect2((source_position+target_position)*.5-Vector2(160,120),Vector2(320,240))
	elif conditions.action == "攻撃" and actor.spec.id == "ram_sentry": bounds = Rect2((source_position+target_position)*.5-Vector2(280,200),Vector2(560,400))
	if is_beetle():
		preload("res://scripts/visuals/character_rig8.gd").enabled = true
		if conditions.action=="攻撃" and conditions.get("scenario","target")=="wall":
			# Deliberately arranged first attack: reflect at a wall toward an offset target.
			var bounce_field=arena.definition.duplicate(true)
			bounce_field.walls.append(Rect2(source_position+Vector2(130,-80),Vector2(16,280)))
			assert(arena.configure_field(bounce_field,0).is_empty())
			target_position=source_position+facing()*150+Vector2(-1,1).normalized()*100
			target.reset(target_position)
			actor.attack_phase="windup";actor.attack_angle=facing().angle();actor.attack_time=actor.spec.windup
		target.sync_visual()
		actor.rig.guides = conditions.get("guides",false)
		if conditions.action == "攻撃": bounds = Rect2(source_position-Vector2(80,90),Vector2(450,420))
	target.get_node("Identity").hide()
	target.get_node("Aim").hide()
	queue_redraw()

func advance(dt: float) -> void:
	time += dt
	ticks += 1
	if players.size() != 2: return
	var actor = players[0]
	var target = players[1]
	if conditions.action == "攻撃":
		actor.step(dt,0,target,arena)
		session._step_delayed_shots(dt)
		session._step_projectiles(dt)
		damage_total += maxf(0,target.max_hp-target.state.hp)
		target.state.hp = target.max_hp
		target.state.inv = maxf(0,target.state.inv-dt)
		target.state.pos = target_position
		target.sync_visual()
		target.get_node("Identity").hide()
		target.get_node("Aim").hide()
	else:
		var walking: bool = conditions.action == "歩行" and (not is_beetle() or fposmod(time,1.6) < 1.1)
		actor.attack_phase = "chase" if walking else "grace"
		actor.state.angle = facing().angle()
		actor.state.pos = source_position
		actor.previous_visual_position = source_position-facing()*float(actor.spec.speed)*dt if walking else source_position
		actor.advance_visual(dt,walking)
		actor.sync_visual()
	fx.step(dt)
	queue_redraw()
