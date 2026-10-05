extends "res://tests/exploration_treasure_supplies.gd"
# Stationary, invulnerable shooter with perfect aim and ample reserve: not human difficulty.
func run() -> void:
	root.size = Vector2i(1120,800)
	var game = load("res://scenes/game/exploration.tscn").instantiate()
	game.random_floor = true
	game.authored_campaign = true
	root.add_child(game)
	game.set_physics_process(false)
	var rows: Array = []
	for health in [48.0,72.0,96.0]:
		for loadout in [{"gun":20,"relics":[]},{"gun":28,"relics":[]},{"gun":30,"relics":[7,22,1]},{"gun":37,"relics":[]}]:
			game.start_exploration(22)
			game.set_pause_reason("focus",false)
			var room_id: String = game.floor_data.rooms.keys().filter(func(id): return game.floor_data.rooms[id].role == "boss")[0]
			enter(game,room_id)
			game._physics_process(2.5)
			var p = game.players[0]
			var boss = game.players[1]
			boss.state.hp = health
			boss.state.max_hp = health
			p.state.pos = boss.state.pos+Vector2(0,220)
			p.relics = loadout.relics.duplicate()
			p.inventory = [p.new_weapon_entry(loadout.gun)]
			p.state.gun = 0
			p.weapon().reserve = 10000
			p.update_weapon_art()
			game.command_source = func(index,_dt):
				if index != 0: return {}
				return {"dx":0.0,"dy":0.0,"angle":(boss.state.pos-p.state.pos).angle(),"shoot":true}
			var elapsed := 0.0
			var transition := -1.0
			var starts := [0,0]
			var initial: int = p.weapon().clip+p.weapon().reserve
			for tick in range(7200):
				p.state.inv = 100.0
				var phase: String = boss.attack_phase
				game._physics_process(1.0/60)
				elapsed = (tick+1)/60.0
				if boss.second_phase and transition < 0: transition = elapsed
				if phase == "windup" and boss.attack_phase in ["dash","machinegun","salvo","cannon","shockwave","recover"]:
					starts[1 if boss.second_phase else 0] += 1
				if boss.state.hp <= 0: break
			var row: Dictionary = {"hp":health,"gun":loadout.gun,"relics":loadout.relics,"seconds":elapsed,"transition":transition,"attacks":starts,"remaining_hp":boss.state.hp,"spent":-1 if p.infinite_reserve(loadout.gun) else initial-p.weapon().clip-p.weapon().reserve,"infinite":p.infinite_reserve(loadout.gun),"normal_ammo":p.definition().mag+p.definition().stock}
			rows.append(row)
			print(JSON.stringify(row))
			await process_frame
	var output := FileAccess.open("res://.local/boss-durability.json",FileAccess.WRITE)
	output.store_string(JSON.stringify({"mode":"stationary invulnerable perfect aim, ample reserve, real moving boss and collisions","rows":rows},"\t"))
	output.close()
	game.queue_free()
	await process_frame
	quit()
