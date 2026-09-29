extends SceneTree
func _initialize(): call_deferred("run")
func run():
 var game=load("res://scenes/game/combat_lab.tscn").instantiate()
 root.add_child(game)
 game.set_physics_process(false)
 assert(game.launch_test("courtyard",["root_runner_prototype"],0))
 var actor=game.players[1]
 var events:Array=[]
 actor.sound_requested.connect(func(kind,id):events.append(kind))
 actor.attack_phase="windup"
 actor.attack_time=.001
 actor.step(.016,1,game.players[0],game.arena)
 assert(events.count("moss_dash")==1 and not events.has("sentry_windup"))
 game.sound.play_sound("moss_roll",actor.get_instance_id())
 var rolling=game.sound.moss_rollers.values()
 assert(not rolling.is_empty())
 game.set_pause_reason("lab",true)
 for voice in rolling: assert(voice.stream_paused)
 game.set_pause_reason("lab",false)
 actor.recover_tackle("miss")
 for voice in rolling: assert(not voice.playing)
 actor.state.inv=0
 actor.hurt(100)
 assert(not actor.rig.visible and events.count("moss_down")==1)
 assert(not events.has("sentry_down"))
 var remains=get_nodes_in_group("enemy_death_visuals")
 assert(remains.size()==1 and remains[0].moss_rig!=null)
 actor.hurt(100)
 assert(events.count("moss_down")==1)
 remains[0].step(.3)
 assert(is_equal_approx(remains[0].moss_rig.view.death_time,.3))
 remains[0].step(1.3)
 await process_frame
 assert(get_nodes_in_group("enemy_death_visuals").is_empty())
 for key in ["moss_dash","moss_wall","moss_down"]:
  assert(game.sound.GENERATED[key].get_length()>.3)
 # Same-frame starts must remain independent when either creature stops.
 game.sound.play_sound("moss_roll",101)
 game.sound.play_sound("moss_roll",202)
 assert(game.sound.moss_rollers.size()==2)
 var second=game.sound.moss_rollers[202]
 game.sound.play_sound("moss_stop",101)
 assert(second.playing and game.sound.moss_rollers.size()==1)
 game.sound.play_sound("moss_roll_low",202)
 assert(second.pitch_scale<1)
 for owner in range(203,208): game.sound.play_sound("moss_roll",owner)
 assert(game.sound.moss_rollers.size()==6)
 game.sound.pause_boss_audio(true)
 for voice in game.sound.moss_rollers.values(): assert(voice.stream_paused)
 game.sound.pause_boss_audio(false)
 game.sound.set_enabled(false)
 assert(game.sound.moss_rollers.is_empty())
 game.sound.set_enabled(true)
 game.retry_lab()
 assert(game.players[1].rig.visible)
 for phase in ["chase","windup","dash"]:
  game.retry_lab()
  var target=game.players[1]
  target.attack_phase=phase
  target.attack_time=.3
  target.advance_visual(.016,true)
  var pose=target.Rig.attack_pose(target.rig.view)
  var feet=target.rig.feet.duplicate(true)
  target.state.inv=0
  target.hurt(100)
  var dead=get_nodes_in_group("enemy_death_visuals").filter(func(v):return not v.is_queued_for_deletion())
  assert(dead.size()==1)
  assert(dead[0].moss_rig.view.death_pose==pose)
  assert(dead[0].moss_rig.feet==feet)
  dead[0].step(.5)
  assert(dead[0].moss_rig.rotation==0 and dead[0].moss_rig.textures.has("direction8"))
  dead[0].step(.3)
  assert(dead[0].moss_rig.modulate.a==1.0)
 game.queue_free()
 await process_frame
 print("PASS moss presentation: launch, pause, stop, death once, rig cleanup, retry, resources")
 quit()
