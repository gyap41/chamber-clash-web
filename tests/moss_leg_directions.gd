extends SceneTree
func _initialize(): call_deferred("run")
func run():
 var rig=load("res://scripts/visuals/root_runner_rig.gd").new()
 root.add_child(rig)
 var longest:=0.0
 for n in range(8):
  rig.reset_pose()
  var axis=Vector2.from_angle(n*PI/4)
  for tick in range(240):
   var before=rig.feet.duplicate(true)
   rig.advance(1.0/60,axis*1.2,{"phase":"chase"})
   assert(rig.facing_index==n)
   for i in range(6):
    if not before[i].swing and not rig.feet[i].swing: assert(before[i].pos.distance_to(rig.feet[i].pos)<.001)
    var points=rig.leg_points(i)
    longest=maxf(longest,points[0].distance_to(points[2]))
    assert(points[0].distance_to(points[2])<32)
 # Stop preserves facing; windup follows locked aim; reflected recovery faces away.
 rig.advance(.016,Vector2.ZERO,{"phase":"chase","angle":0.0})
 assert(rig.facing_index==7)
 rig.advance(.016,Vector2.ZERO,{"phase":"windup","angle":PI})
 assert(rig.facing_index==4)
 rig.advance(.016,Vector2.ZERO,{"phase":"dash","angle":0.0})
 rig.advance(.016,Vector2.ZERO,{"phase":"recover","angle":PI/2,"remaining":.9,"recovery":.9})
 assert(rig.facing_index==2)
 print("PASS eight direction foot stance; maximum hip-foot reach: ",longest)
 rig.free()
 quit()
