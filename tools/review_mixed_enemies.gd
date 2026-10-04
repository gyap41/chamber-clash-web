extends SceneTree
func _initialize(): call_deferred("run")
func run():
 root.size=Vector2i(1120,800)
 var game=load("res://scenes/game/combat_lab.tscn").instantiate()
 root.add_child(game)
 game.set_physics_process(false)
 var ids=["fire_pouch_lizard","ember_lizard","quillback","iron_quill","ash_ram","triple_ring"]
 for room in ["courtyard","stage_workshop_trial"]:
  assert(game.launch_test(room,ids,0))
  game.test_invincible=true
  var phases={}
  for tick in range(1200):
   game._physics_process(1.0/60)
   for actor in game.players.slice(1):
    phases[actor.spec.id+":"+actor.attack_phase]=true
   if tick in [120,360,720,1100]:
    await process_frame
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png("res://docs/art/production/enemy-animation-v2/mixed-%s-%d.png" % [room,tick])
   if tick==600:
    game.open_lab(true)
    var pos=game.players[1].state.pos
    for n in range(30): game._physics_process(1.0/60)
    assert(game.players[1].state.pos==pos)
    game.open_lab(false)
  print("REVIEW ",room," phases: ",phases.keys())
  var palettes=[]
  for actor in game.players.slice(1):
   if actor.material != null: palettes.append(actor.material)
   actor.state.inv=0
   actor.hurt(100)
  var inherited=0
  for remains in get_nodes_in_group("enemy_death_visuals"):
   if remains.material in palettes: inherited+=1
  assert(inherited==2,"Both variant palettes must survive death")
  for tick in range(90): game._physics_process(1.0/60)
 game.queue_free()
 await process_frame
 print("PASS: six enemies, two floors, 20 seconds each, pause/resume and death")
 quit()
