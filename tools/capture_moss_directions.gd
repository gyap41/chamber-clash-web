extends SceneTree
func _initialize(): call_deferred("run")
func run():
 root.size=Vector2i(1120,800)
 var bg=ColorRect.new();bg.color=Color("24302e");bg.size=Vector2(1120,800);root.add_child(bg)
 var rigs=[]
 for i in range(9):
  var center=Vector2(185+(i%3)*365,130+(i/3)*250)
  var label=Label.new();label.text=["EAST","SOUTHEAST","SOUTH","SOUTHWEST","WEST","NORTHWEST","NORTH","NORTHEAST","DEFEATED"][i];label.position=center+Vector2(-90,-90);root.add_child(label)
  var rig=load("res://scripts/visuals/root_runner_rig.gd").new();rig.position=center;rig.scale=Vector2.ONE*3;root.add_child(rig);rigs.append(rig)
  if i==8: rig.view={"death_time":.7}
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.local/moss-directions"))
 for tick in range(72):
  for i in range(8):
   var axis=Vector2.from_angle(i*PI/4)
   rigs[i].advance(1.0/30,axis*2.4,{"phase":"chase","angle":axis.angle()})
   assert(rigs[i].facing_index==i)
  await process_frame
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://.local/moss-directions/%03d.png"%tick)
 print("PASS eight facing walk capture / 72 frames")
 quit()
