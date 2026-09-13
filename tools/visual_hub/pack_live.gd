extends SceneTree
const Index = preload("res://tools/visual_hub/asset_index.gd")
func _initialize(): call_deferred("run")
func run():
 var base="res://.local/visual-hub/live/"
 var zip=ZIPReader.new()
 assert(zip.open(base+"base.zip")==OK)
 var pack=PCKPacker.new()
 assert(pack.pck_start(base+"hub-next.pck")==OK)
 var sources={}
 var number=0
 for name in zip.get_files():
  if name.ends_with("/"): continue
  var temp=base+"part.tmp"
  var file=FileAccess.open(temp,FileAccess.WRITE); file.store_buffer(zip.read_file(name)); file.close()
  # PCKPacker reads the file on flush, so each entry needs its own source.
  number+=1
  var saved=base+"parts/"+str(number)
  DirAccess.make_dir_recursive_absolute(base+"parts")
  DirAccess.rename_absolute(temp,saved)
  sources["res://"+name]=saved
 var index=Index.new()
 for root_path in ["res://scripts","res://scenes","res://data","res://assets","res://tools/visual_hub"]:
  for path in index.files(root_path,["gd","tscn","tres","json","png","svg","gdshader"]):
   var relative=path.trim_prefix("res://")
   if root_path=="res://assets" and not zip.file_exists(relative+".import") and not zip.file_exists(relative): continue
   if root_path=="res://tools/visual_hub" and "/web/" in path: continue
   sources[path]=path
 ProjectSettings.set_setting("application/run/main_scene","res://tools/visual_hub/live_preview.tscn")
 ProjectSettings.set_setting("display/window/per_pixel_transparency/allowed",true)
 ProjectSettings.set_setting("display/window/per_pixel_transparency/enabled",true)
 ProjectSettings.save_custom(base+"project.binary")
 sources["res://project.binary"]=base+"project.binary"
 for path in sources: assert(pack.add_file(path,sources[path])==OK)
 assert(pack.flush()==OK)
 assert(DirAccess.rename_absolute(base+"hub-next.pck",base+"hub.pck")==OK)
 print("PASS: live Hub PCK built");quit()
