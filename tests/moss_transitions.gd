extends SceneTree
func _initialize(): call_deferred("run")
func run():
 var rig=load("res://scripts/visuals/root_runner_rig.gd")
 var wind=rig.attack_pose({"phase":"windup","windup":.5,"remaining":0.0})
 var dash=rig.attack_pose({"phase":"dash","roll_turns":0.0})
 assert(absf(wind.lean-dash.lean)<.001 and wind.curl==dash.curl)
 for turn in [0.0,.1,.45,.9,1.8,4.2]:
  dash=rig.attack_pose({"phase":"dash","roll_turns":turn})
  var stop=rig.attack_pose({"phase":"recover","roll_turns":turn,"remaining":.9,"recovery":.9})
  assert(absf(stop.hop-dash.hop)<.001 and stop.roll==dash.roll)
  stop=rig.attack_pose({"phase":"recover","roll_turns":turn,"remaining":.72,"recovery":.9})
  assert(stop.roll>=turn and stop.roll-turn<=.25001)
 var game=load("res://scenes/game/combat_lab.tscn").instantiate()
 root.add_child(game);game.set_physics_process(false)
 for id in game.EnemyScripts:
  game.launch_test("courtyard",[id],0)
  var events=[]
  game.players[1].sound_requested.connect(func(kind,_id):events.append(kind))
  game.players[1].state.inv=0
  game.players[1].hurt(100)
  game.players[1].hurt(100)
  assert(events.count("enemy_defeat")==1,"Defeat cue must occur once: "+id)
 assert(game.sound.GENERATED.enemy_defeat.get_length()>.3)
 game.queue_free()
 await process_frame
 await process_frame
 print("PASS: tuck/dash/recovery continuity; 8 enemy defeat cues exactly once")
 quit()
