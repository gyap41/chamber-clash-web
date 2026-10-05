extends SceneTree
func _initialize(): call_deferred("run")
func run():
 var game=load("res://scenes/game/exploration.tscn").instantiate()
 game.random_floor=true;game.authored_campaign=true
 root.add_child(game);game.set_physics_process(false)
 var types={}
 var fought=0
 for seed_value in range(10):
  game.start_exploration(seed_value)
  assert(game.floor_data.production and game.floor_data.errors.is_empty())
  for id in game.room_catalog:
   var meta=game.floor_data.rooms[id]
   var room=game.room_catalog[id]
   types[meta.template_id]=true
   game.Encounter.retire(game)
   game.clear_enemy_deaths()
   assert(game.switch_field(room.field.duplicate(true)).is_empty())
   game.exploration.enter_room(id,meta.template_id)
   game.players[0].state.hp=4
   game.Encounter.begin(game)
   game.rebuild_doors()
   assert(game.phase!="result","Spawn failure seed %s %s"%[seed_value,id])
   if meta.role in ["normal","boss"]:
    assert(game.players.size()>1)
    if meta.role=="boss": game.BossFlow.finish_intro(game)
    for actor in game.players.slice(1):
     assert(not game.arena.solid(actor.state.pos,actor.radius))
     actor.state.inv=0
     actor.hurt(1000)
    game._physics_process(.016)
    assert(game.exploration.encounter_status=="cleared",str([seed_value,id,meta.role,game.phase,game.paused,game.result,game.players.map(func(p):return p.state.hp)]))
    fought+=1
   elif meta.role=="treasure":
    assert(not game.Reward.current(game).is_empty())
  assert(game.exploration.room_states.values().filter(func(r):return r.get("reward",{}).get("source","")=="first_clear").size()==1)
  assert(game.exploration.room_states.values().all(func(r):return r.get("reward",{}).get("source","")!="third_clear"))
 print("PASS production floor: 10 seeds, encounters=",fought," template coverage=",types.size())
 game.queue_free()
 await process_frame
 quit()
