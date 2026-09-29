extends SceneTree
func _initialize():
 var path="res://assets/first-workshop/root-runner-prototype/directions-v1.png"
 var raw=Image.load_from_file(ProjectSettings.globalize_path(path))
 var anchors=[Vector2(216,239),Vector2(625,242),Vector2(1033,232),Vector2(224,626),Vector2(627,627),Vector2(1053,632),Vector2(217,1023),Vector2(626,1023),Vector2(1043,1037)]
 var data={"shell_width":290.0*1254/1280,"regions":{},"anchors":{}}
 assert(raw.get_size()==Vector2i(1254,1254))
 for i in range(anchors.size()): anchors[i]*=1254.0/1280
 assert(raw.get_pixel(0,0).a<.01)
 for i in range(9):
  var lo=Vector2i(int((i%3)*1254/3.0),int((i/3)*1254/3.0))
  var hi=Vector2i(int((i%3+1)*1254/3.0),int((i/3+1)*1254/3.0))
  var low=hi
  var high=lo
  for y in range(lo.y,hi.y):
   for x in range(lo.x,hi.x):
    if raw.get_pixel(x,y).a>.1:
     low=low.min(Vector2i(x,y));high=high.max(Vector2i(x+1,y+1))
  var key=str(i)
  data.regions[key]=[low.x,low.y,high.x-low.x,high.y-low.y]
  data.anchors[key]=[anchors[i].x-low.x,anchors[i].y-low.y]
 var f=FileAccess.open("res://assets/first-workshop/root-runner-prototype/directions-regions-v1.json",FileAccess.WRITE)
 f.store_string(JSON.stringify(data,"\t"))
 print("PASS directional atlas regions / alpha / common shell scale")
 quit()
