extends SceneTree
const Live=preload("res://tools/visual_hub/live_preview.gd")
func _initialize():call_deferred("run")
func run():
 var live=Live.new();root.add_child(live);live.set_process(false)
 var entries=[]
 for character in range(8):
  for action in ["待機","歩行","回避"]:
   entries.append({"key":str(character)+action,"id":"character:"+str(character),"rect":[250,80,200,160],"conditions":{"action":action,"weapon":20}})
 live.apply({"slots":entries,"signature":"first","playing":false,"clip":[224,0,1200,800]})
 assert(live.slots.size()==24)
 for i in range(12):live.advance(1.0/60)
 var before=live.elapsed;live._process(.1);assert(is_equal_approx(before,live.elapsed))
 for entry in entries:entry.conditions.weapon=10
 live.apply({"slots":entries,"signature":"weapon10","playing":false,"clip":[224,0,1200,800]})
 assert(live.slots.size()==24 and live.elapsed==0)
 for slot in live.slots.values():assert(slot.adapter.players[0].inventory[0].id==10)
 live.apply({"slots":entries.slice(0,3),"signature":"weapon10","playing":false,"clip":[224,0,1200,800]})
 assert(live.slots.size()==3)
 live.apply({"slots":[],"signature":"weapon10","playing":false,"clip":[224,0,1200,800]})
 assert(live.slots.is_empty())
 live.free();print("PASS: 24 character cells / weapon switch / paused clock / offscreen release");quit()
