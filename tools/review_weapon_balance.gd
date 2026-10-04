extends SceneTree
# Isolated exploration benchmark, not a ranking of crowd control or human accuracy.
const Field = preload("res://scripts/world/field_definition.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var game = load("res://scenes/game/combat_lab.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	var rows: Array = []
	for distance in [40,80,180,320]:
		for id in range(38):
			assert(game.launch_test("courtyard",["fire_pouch_lizard"],id))
			game.set_pause_reason("focus",false)
			var field = Field.new()
			field.field_id = "weapon-benchmark"
			field.field_rect = Rect2(0,0,2000,1200)
			field.fighter_bounds = Rect2(14,14,1972,1172)
			field.projectile_bounds = field.field_rect
			field.spawns = PackedVector2Array([Vector2(800,600)])
			assert(game.arena.configure_field(field,1).is_empty())
			var p = game.players[0]
			var target = game.players[1]
			p.relics.clear()
			p.weapon_mods.clear()
			p.reset(Vector2(800,600))
			p.inventory = [p.new_weapon_entry(id)]
			p.state.gun = 0
			p.weapon().reserve = 10000
			p.state.angle = 0
			target.prepare(Vector2(800+distance,600))
			target.state.hp = 10000.0
			target.state.max_hp = 10000.0
			var row = {"id":id,"name":p.definition().name,"distance":distance,"ttk_hp3":-1.0,"ttk_hp8":-1.0,"triggers":0,"damage_10s":0.0}
			var command = {"dx":0.0,"dy":0.0,"angle":0.0,"shoot":true}
			for tick in range(1200):
				var dt := 1.0/120.0
				game.combat._step_delayed_shots(dt)
				if p.step(dt,0,target,game.arena,false,command):
					game.combat.fire(0)
					row.triggers += 1
				target.state.inv = maxf(0.0,target.state.inv-dt)
				game.combat._step_projectiles(dt)
				game.combat._step_wells(dt)
				var damage: float = 10000.0-target.state.hp
				for hp in [3,8]:
					var key = "ttk_hp%d"%hp
					if row[key]<0 and damage>=hp-.00001: row[key]=(tick+1)*dt
			row.damage_10s = 10000.0-target.state.hp
			rows.append(row)
			await process_frame
	# A fresh projectile hit can outlast an entire melee swing. Record the gap
	# separately from sector geometry; this does not bypass the damage guard.
	var melee_cases: Array = []
	var p = game.players[0]
	var target = game.players[1]
	for gap in [0.0,0.1,0.23]:
		p.reset(Vector2(800,600))
		p.state.angle = 0.0
		target.prepare(Vector2(840,600))
		assert(target.hurt(.55,123,false,{},p))
		target.state.inv = maxf(0.0,target.state.inv-gap)
		var before: float = target.state.hp
		p.try_melee(0,[],target,game.arena)
		for tick in range(24):
			p.state.slash = maxf(0.0,p.state.slash-1.0/120.0)
			target.state.inv = maxf(0.0,target.state.inv-1.0/120.0)
			p.resolve_melee_hits(0,[],target,game.arena)
		melee_cases.append({"gap_after_bullet":gap,"melee_damage":before-target.state.hp})
	var out = FileAccess.open("res://.local/weapon-balance.json",FileAccess.WRITE)
	out.store_string(JSON.stringify({"step_hz":120,"duration":10,"target_radius":18,"stationary":true,"relics":[],"mods":[],"rows":rows,"melee_after_bullet":melee_cases},"\t"))
	out.close()
	game.queue_free()
	await process_frame
	print("BALANCE: 152 stationary cases saved to .local/weapon-balance.json")
	quit()
