extends SceneTree
const Index = preload("res://tools/visual_hub/asset_index.gd")
const Registry = preload("res://tools/visual_hub/preview_registry.gd")
const EnemyRegistry = preload("res://scripts/catalog/enemy_registry.gd")
const Store = preload("res://tools/visual_hub/conditions.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var index := Index.new()
	index.reload()
	var enemies := index.enumerate("","敵").filter(func(item): return item.game)
	# The hub lists exactly the enemies registered for exploration encounters.
	assert(enemies.size() == EnemyRegistry.ENEMIES.size())
	for id in EnemyRegistry.ENEMIES: assert(enemies.any(func(item): return item.id == "enemy:"+id),id)
	var registry := Registry.new()
	for enemy in enemies:
		assert(enemy.preview and enemy.game and enemy.method == "enemy")
		for direction in range(4):
			for action in ["待機","歩行","攻撃"]:
				var settings := Store.defaults()
				settings.action = action
				settings.aim = direction
				var adapter = registry.create_preview(root,enemy,settings)
				assert(adapter.failure.is_empty())
				var max_shots := 0
				var attacking := false
				for tick in range(360):
					adapter.advance(1.0/60)
					max_shots = maxi(max_shots,adapter.shots.size())
					if adapter.players[0].attack_phase in ["windup","dash","spit","recover"]: attacking = true
				assert(adapter.players[1].state.hp > 0)
				if action == "攻撃":
					assert(attacking,enemy.id+" failed to attack direction "+str(direction))
					if enemy.definition.range > 100 and enemy.definition.id not in ["ram_sentry","root_runner_prototype"]: assert(max_shots > 0,enemy.id) # dash attackers fire nothing
				elif action == "歩行": assert(adapter.players[0].gait_phase > 0)
				else: assert(adapter.players[0].gait_phase == 0)
				adapter.finish()
				assert(adapter.players.is_empty() and adapter.shots.is_empty())
				adapter.free()
	print("PASS: ",enemies.size()," enemies x 4 directions x idle/walk/real attack, target survival, projectiles, cleanup")
	quit()
