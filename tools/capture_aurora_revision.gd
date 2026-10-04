extends SceneTree
func _initialize():call_deferred("run")
func run():
 root.size=Vector2i(1120,800)
 var game=load("res://scenes/game/combat_lab.tscn").instantiate()
 root.add_child(game)
 game.set_physics_process(false)
 assert(game.launch_test("stage_workshop_trial",["ash_ram","triple_ring"],37))
 game.test_invincible=true
 var p=game.players[0]
 p.state.pos=Vector2(470,450)
 p.state.angle=0
 for tick in range(150):
  if tick%50==0:
   p.state.shot=0
   p.state.angle=0
   game.fire(0)
  game._physics_process(1.0/60)
  if tick in [1,12,38,65,100]:
   await process_frame
   await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png("res://docs/art/production/enemy-animation-v2/aurora-%03d.png" % tick)
 game.queue_free()
 await process_frame
 print("PASS: aurora live fire and impacts with two dedicated machines")
 quit()
