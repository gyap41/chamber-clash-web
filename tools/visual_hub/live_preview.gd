extends Node
const Index=preload("res://tools/visual_hub/asset_index.gd")
const Store=preload("res://tools/visual_hub/conditions.gd")
const Registry=preload("res://tools/visual_hub/preview_registry.gd")
const Overlay=preload("res://tools/visual_hub/inspection_overlay.gd")
var index=Index.new()
var registry=Registry.new()
var slots={}
var bridge
var callback
var elapsed=0.0
var accumulator=0.0
var playing=true
var speed=1.0
var signature=""
var fps_clock=0.0
var frame_count=0
var layout_revision=0
var clip: Control
func _ready():
 get_viewport().transparent_bg=true
 get_window().content_scale_size=Vector2i.ZERO
 clip=Control.new();clip.clip_contents=true;add_child(clip)
 index.reload();index.install_game_snapshot()
 if OS.has_feature("web"):
  bridge=JavaScriptBridge.get_interface("window")
  callback=JavaScriptBridge.create_callback(receive)
  bridge.hubReceive=callback;bridge.hubReady()
  RenderingServer.frame_post_draw.connect(paint_frame)
func paint_frame():
 if bridge!=null: bridge.hubPaint(layout_revision)
func receive(args):
 var value=JSON.parse_string(str(args[0]))
 if not value is Dictionary: return
 apply(value)
func apply(value: Dictionary):
 layout_revision=int(value.get("revision",0))
 playing=bool(value.get("playing",true));speed=clampf(float(value.get("speed",1)),.25,2)
 var next_signature=str(value.get("signature",""))
 if next_signature!=signature:
  clear_slots();elapsed=0;accumulator=0;signature=next_signature
 var clip_rect=value.get("clip",[0,0,1280,720])
 clip.position=Vector2(clip_rect[0],clip_rect[1]);clip.size=Vector2(clip_rect[2],clip_rect[3])
 var keep={}
 for entry in value.get("slots",[]).slice(0,24):
  var key=str(entry.key);keep[key]=true
  if not slots.has(key):
   var item=index.detail(str(entry.id))
   if item.is_empty(): continue
   var conditions=Store.normalize(entry.get("conditions",{}))
   var container=SubViewportContainer.new();container.mouse_filter=Control.MOUSE_FILTER_IGNORE;container.stretch=true;clip.add_child(container)
   var viewport=SubViewport.new();viewport.disable_3d=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;container.add_child(viewport)
   var adapter=registry.create_preview(viewport,item,conditions)
   var overlay=Overlay.new();overlay.adapter=adapter;adapter.add_child(overlay)
   slots[key]={"container":container,"viewport":viewport,"adapter":adapter,"conditions":conditions}
   var steps=roundi(elapsed/(1.0/60))
   for tick in range(steps): adapter.advance(1.0/60)
  var slot=slots[key];var rect=entry.rect
  slot.container.position=Vector2(rect[0],rect[1])-clip.position
  slot.container.size=Vector2(maxf(1,rect[2]),maxf(1,rect[3]))
  var bounds: Rect2=slot.adapter.bounds
  if slot.adapter.record.kind=="キャラ": bounds=Rect2(slot.adapter.source_position-Vector2(64,72),Vector2(128,96))
  if slot.adapter.record.kind=="武器" and slot.conditions.action in ["単発","連射"]:
   var scene=str(slot.conditions.get("scenario","target"))
   if scene=="flight":
    var center=slot.adapter.source_position+slot.adapter.direction(int(slot.conditions.aim))*160
    bounds=Rect2(center-Vector2(160,120),Vector2(320,240))
   elif scene in ["target","effect","wall"]:
    var center=slot.adapter.target_position if scene!="wall" else Vector2(580,300)
    bounds=Rect2(center-Vector2(180,120),Vector2(360,240))
  var zoom=float(slot.conditions.zoom)
  if slot.conditions.fit: zoom=minf(rect[2]/maxf(bounds.size.x,1),rect[3]/maxf(bounds.size.y,1))*.85
  slot.viewport.canvas_transform=Transform2D(0,Vector2.ONE*zoom,0,slot.container.size*.5-bounds.get_center()*zoom)
 for key in slots.keys():
  if not keep.has(key): remove_slot(key)
 if value.get("restart",false): reset_time()
 if value.get("step",false): advance(1.0/60)
func remove_slot(key):
 slots[key].adapter.finish();slots[key].container.free();slots.erase(key)
func clear_slots():
 for key in slots.keys(): remove_slot(key)
func reset_time():
 elapsed=0;accumulator=0
 for slot in slots.values():
  var item=slot.adapter.record.duplicate(true)
  slot.adapter.finish();slot.adapter.free()
  slot.adapter=registry.create_preview(slot.viewport,item,slot.conditions)
  var overlay=Overlay.new();overlay.adapter=slot.adapter;slot.adapter.add_child(overlay)
func advance(dt):
 elapsed+=dt
 for slot in slots.values(): slot.adapter.advance(dt)
 if elapsed>=6: reset_time()
func _process(delta):
 if playing:
  accumulator+=minf(delta,.1)*speed
  while accumulator>=1.0/60:
   accumulator-=1.0/60;advance(1.0/60)
 fps_clock+=delta;frame_count+=1
 if fps_clock>=1 and bridge!=null:
  var errors=[]
  var metrics={}
  for key in slots:
   var a=slots[key].adapter
   metrics[key]={"damage":a.damage_total,"projectiles":a.shots.size(),"wells":a.wells.size(),"weapon":a.players[0].weapon().id if not a.players.is_empty() and a.players[0].has_weapon() else -1}
  for slot in slots.values():
   if not slot.adapter.failure.is_empty(): errors.append(slot.adapter.failure)
  bridge.hubSend(JSON.stringify({"ready":true,"slots":slots.size(),"time":elapsed,"fps":frame_count/fps_clock,"errors":errors,"signature":signature,"metrics":metrics}))
  fps_clock=0;frame_count=0
func _exit_tree(): clear_slots()
