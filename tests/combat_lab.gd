extends SceneTree
func _initialize(): call_deferred("run")
func run():
 var game=load("res://scenes/game/combat_lab.tscn").instantiate()
 root.add_child(game)
 game.set_physics_process(false)
 assert(game.paused and game.lab_panel.visible)
 # Every authored room and every registered enemy is available in the lab.
 assert(game.room_ids.size()==game.room_catalog.size() and game.lab_counts.size()==game.EnemyScripts.size())
 for id in game.Authored.ORDER: assert(id in game.room_ids,id)
 for id in game.room_ids:
  assert(game.launch_test(id,[],0),"Room failed: "+id)
  assert(game.players.size()==1 and game.exploration.room_id==id)
 for id in game.EnemyScripts:
  assert(game.launch_test("courtyard",[id],0),"Enemy failed: "+id)
  assert(game.players.size()==2)
  game.test_invincible=true
  for tick in range(180): game._physics_process(1.0/60)
  assert(game.players[0].state.hp==game.players[0].max_hp)
 assert(game.launch_test("courtyard",["root_runner_prototype","workshop_sentry","ring_sentry"],1))
 assert(game.players.size()==4 and game.players[0].inventory[0].id==1)
 game.open_lab(true)
 var pos=game.players[1].state.pos
 for tick in range(60): game._physics_process(1.0/60)
 assert(game.players[1].state.pos==pos)
 game.players[0].state.hp=0
 game.open_lab(false)
 game._physics_process(1.0/60)
 assert(game.phase=="result")
 game.retry_lab()
 assert(game.phase=="play" and game.players.size()==4 and game.players[0].state.hp>0)
 assert(not game.launch_test("bad",[],0))
 assert(not game.launch_test("courtyard",["bad"],0))
 assert(not game.launch_test("courtyard",Array(game.EnemyScripts.keys()),0))
 game.queue_free()
 await process_frame
 await process_frame
 print("PASS combat_lab: all rooms, all registered enemies, mixed combat, pause, death/retry, invalid requests")
 quit()
