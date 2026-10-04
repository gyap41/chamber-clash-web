extends SceneTree
# Diagnostic controller: full knowledge of nearby enemies/bullets, not a human playtest.
const Nav = preload("res://scripts/ai/cpu_navigation.gd")
var game
func _initialize() -> void: call_deferred("run")
func command(index: int, _dt: float) -> Dictionary:
	var p = game.players[index]
	var result = {"dx":0.0,"dy":0.0,"angle":p.state.angle,"shoot":false}
	if index!=0: return result
	var enemy = game.roster.nearest(0,game.players,p.state.pos)
	if enemy==null: return result
	var best_score := -INF
	var best := Vector2.ZERO
	for n in range(9):
		var direction := Vector2.ZERO if n==8 else Vector2.from_angle(n*TAU/8)
		var point: Vector2 = p.state.pos+direction*70
		if not Nav.segment_clear(game.arena,p.state.pos,point,p.radius): continue
		var score: float = -absf(point.distance_to(enemy.state.pos)-220)
		for actor in game.players.slice(1):
			if actor.state.hp>0: score-=maxf(0,120-point.distance_to(actor.state.pos))*3
		for shot in game.shots:
			if shot.state.owner==0: continue
			var future: Vector2 = shot.state.pos+shot.state.velocity*.2
			score-=maxf(0,80-point.distance_to(future))*5
		if score>best_score:
			best_score=score
			best=direction
	result.dx=best.x
	result.dy=best.y
	result.angle=(enemy.state.pos-p.state.pos).angle()
	result.shoot=not game.arena.line_blocked(p.state.pos,enemy.state.pos)
	result.melee=p.state.pos.distance_to(enemy.state.pos)<65
	result.dodge=(enemy.attack_phase=="windup" and p.state.pos.distance_to(enemy.state.pos)<120) or game.shots.any(func(s):return s.state.owner!=0 and s.state.pos.distance_to(p.state.pos)<65)
	return result
func run() -> void:
	root.size=Vector2i(1120,800)
	game=load("res://scenes/game/exploration.tscn").instantiate()
	game.random_floor=true
	game.authored_campaign=true
	root.add_child(game)
	game.set_physics_process(false)
	var rows: Array=[]
	for seed_value in range(3):
		game.start_exploration(seed_value)
		game.set_pause_reason("focus",false)
		for id in game.floor_data.rooms:
			var meta: Dictionary=game.floor_data.rooms[id]
			if meta.role!="normal": continue
			var room=game.room_data(id)
			for door in room.doors:
				game.Encounter.retire(game)
				game.clear_enemy_deaths()
				assert(game.switch_field(room.field).is_empty())
				game.exploration.enter_room(id,meta.template_id)
				game.players[0].move_to_room(door.arrival)
				game.Encounter.begin(game)
				assert(game.phase=="play" and game.players.size()>1)
				var cells:=0
				for y in range(int(game.arena.field_rect.position.y),int(game.arena.field_rect.end.y),64):
					for x in range(int(game.arena.field_rect.position.x),int(game.arena.field_rect.end.x),64):
						if not game.arena.solid(Vector2(x+32,y+32),26): cells+=1
				var hp:=0.0
				var nearest:=INF
				for actor in game.players.slice(1):
					assert(not game.arena.solid(actor.state.pos,actor.radius))
					assert(not Nav.combat_path(game.arena,actor.state.pos,door.arrival,Vector2(0,54),16384).is_empty())
					hp+=actor.state.hp
					nearest=minf(nearest,actor.state.pos.distance_to(door.arrival))
				assert(nearest>=260)
				rows.append({"seed":seed_value,"room":id,"template":meta.template_id,"arrival":[door.arrival.x,door.arrival.y],"clear_cells":cells,"enemies":game.exploration.room_state(id).enemy_ids.duplicate(),"hp":hp,"nearest":nearest})
				await process_frame
			for actor in game.players.slice(1): actor.state.hp=0
			game._physics_process(.01)
	var samples=rows.filter(func(row):return row.seed==2)
	samples.sort_custom(func(a,b):return a.clear_cells<b.clear_cells)
	var results: Array=[]
	var stress: Dictionary=samples[-1].duplicate(true)
	stress.enemies=["ash_ram","triple_ring","ember_lizard","iron_quill","runner_sentry","fire_pouch_lizard"]
	stress["stress"]=true
	for sample in [samples[0],samples[samples.size()/2],samples[-1],stress]:
		for weapon in [20,28]:
			game.start_exploration(sample.seed)
			game.set_pause_reason("focus",false)
			game.Encounter.retire(game)
			game.clear_enemy_deaths()
			assert(game.switch_field(game.room_data(sample.room).field).is_empty())
			game.exploration.enter_room(sample.room,sample.template)
			var p=game.players[0]
			p.reset(Vector2(sample.arrival[0],sample.arrival[1]))
			p.rally_enabled=false
			p.relics.clear()
			p.weapon_mods.clear()
			p.inventory=[p.new_weapon_entry(weapon)]
			p.state.gun=0
			p.update_weapon_art()
			var initial: int=p.weapon().clip+p.weapon().reserve
			game.exploration.room_state(sample.room).enemy_ids=sample.enemies.duplicate()
			assert(game.Encounter.spawn(game,game.exploration.room_state(sample.room)))
			game.command_source=command
			var elapsed:=0.0
			for tick in range(1800):
				game._physics_process(1.0/60)
				elapsed=(tick+1)/60.0
				if "--capture" in OS.get_cmdline_user_args() and weapon==28 and tick in [119,479]:
					game.FollowCamera.follow(game.arena.get_node("CombatCamera"),game.arena.field_rect,p.state.pos,true)
					game.refresh_hud()
					await process_frame
					await RenderingServer.frame_post_draw
					var path="res://.local/encounter-%s-%s-%d.png"%[sample.template,"stress" if sample.get("stress",false) else "normal",tick]
					assert(root.get_texture().get_image().save_png(path)==OK)
					game.set_pause_reason("focus",false)
				if p.state.hp<=0 or game.players.slice(1).all(func(a):return a.state.hp<=0): break
			# The normal defeat flow retires enemies. Do not misreport that as a clear.
			var survivors: int=-1 if p.state.hp<=0 else game.players.slice(1).filter(func(a):return a.state.hp>0).size()
			var outcome: String="dead" if p.state.hp<=0 else ("cleared" if survivors==0 else "timeout")
			results.append({"template":sample.template,"stress":sample.get("stress",false),"weapon":weapon,"enemies":game.exploration.room_state(sample.room).enemy_ids.duplicate(),"seconds":elapsed,"hp_left":p.state.hp,"outcome":outcome,"survivors":survivors,"finite_ammo_used":initial-p.weapon().clip-p.weapon().reserve if weapon!=20 else -1})
			await process_frame
	var out=FileAccess.open("res://.local/encounter-balance.json",FileAccess.WRITE)
	out.store_string(JSON.stringify({"entries":rows,"controller_trials":results,"human_difficulty_verified":false},"\t"))
	out.close()
	game.queue_free()
	await process_frame
	print("REVIEW: ",rows.size()," room entries, 8 diagnostic controller trials saved")
	quit()
