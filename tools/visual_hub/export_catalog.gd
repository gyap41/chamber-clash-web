extends SceneTree
# Read-only Collector. Export is derived metadata, never a gameplay catalog.
const Index = preload("res://tools/visual_hub/asset_index.gd")
const Store = preload("res://tools/visual_hub/conditions.gd")
const OUTPUT = Store.DIRECTORY+"/catalog.json"
var hashes: Dictionary = {}
var scene_cache: Dictionary = {}
func _initialize() -> void: call_deferred("run")
func digest(path: String) -> String:
	if not hashes.has(path): hashes[path]=FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "missing"
	return hashes[path]
func allowed(path: String) -> bool:
	return path.begins_with("res://") and not ".." in path and path.get_extension() in ["gd","tscn","tres","png","svg","gif","wav","mp3","ogg","ttf","gdshader","json"] and (path.begins_with("res://assets/") or path.begins_with("res://scripts/") or path.begins_with("res://scenes/") or path.begins_with("res://data/") or path.begins_with("res://docs/") or path.begins_with("res://tests/"))
func run() -> void:
	var index:=Index.new(); index.reload("res://data/catalog.json","res://data/weapon_visuals.json",true)
	var game_code := ""
	for path in index.files("res://scripts",["gd"])+index.files("res://scenes",["tscn"])+index.files("res://assets/shaders",["gdshader"])+index.files("res://tools/visual_hub",["gd"]): game_code+=path+digest(path)
	var code_hash:=game_code.sha256_text()
	var output: Array = []
	var counts := {}
	for item in index.records:
		var references: Array = []
		var content := JSON.stringify(item.definition)+JSON.stringify(item.get("profile",{}))
		var modified := 0
		for ref in item.references:
			if not allowed(ref.path): continue
			var exists:=FileAccess.file_exists(ref.path)
			var hash:=digest(ref.path)
			var uid: int=ResourceLoader.get_resource_uid(ref.path) if exists and ResourceLoader.exists(ref.path) else -1
			references.append({"path":ref.path,"relation":ref.relation,"reason":ref.reason,"exists":exists,"hash":hash,"uid":ResourceUID.id_to_text(uid) if uid!=-1 else ""})
			# Catalog record values are hashed independently of unrelated entries.
			if ref.path not in ["res://data/catalog.json","res://data/weapon_visuals.json"]: content+=ref.path+hash
			if exists: modified=maxi(modified,FileAccess.get_modified_time(ref.path))
		var facts := {}
		for key in ["desc","type","rarity","rate","speed","damage","mag","stock","hp","reload","dodge","gun","role","field_id","size","actors"]:
			if item.definition.has(key): facts[key]=item.definition[key]
		if item.kind in ["武器","レリック"]:
			var entry = "gun:"+str(int(item.definition.id)) if item.kind=="武器" else int(item.definition.id)
			facts["price"]=preload("res://scripts/catalog/shop_catalog.gd").price(entry)
			facts["shape"]=preload("res://scripts/game/build_grid.gd").shape_of(entry).map(func(cell): return [cell.x,cell.y])
			facts["effect"]=item.definition.get("desc",item.definition.get("note",""))
		var image_path: String=item.image if allowed(item.image) else ""
		var source_hash: String=(content+code_hash if item.method in ["actor","stage"] else content).sha256_text()
		output.append({"id":item.id,"name":item.name,"kind":item.kind,"status":item.status,"image":image_path,"image_hash":digest(image_path) if not image_path.is_empty() else "","source_hash":source_hash,"modified":modified,"defined":item.defined,"assets":item.assets,"game":item.game,"preview":item.preview,"method":item.method,"issues":item.issues,"facts":facts,"references":references,"users":item.users.filter(allowed),"related":item.related})
		if item.kind!="素材ファイル": counts[item.kind]=int(counts.get(item.kind,0))+1
	output.sort_custom(func(a,b): return a.id.naturalnocasecmp_to(b.id)<0)
	var manifest := {"schema_version":1,"generated_at":Time.get_datetime_string_from_system(true),"engine":Engine.get_version_info().string,"renderer":"gl_compatibility","code_hash":code_hash,"records":output,"counts":counts,"errors":index.errors,"fingerprint":JSON.stringify(output).sha256_text()}
	DirAccess.make_dir_recursive_absolute(Store.DIRECTORY)
	if Store.save(OUTPUT+".tmp",manifest)!=OK or DirAccess.rename_absolute(OUTPUT+".tmp",OUTPUT)!=OK:
		push_error("Visual Hub metadata output failed"); quit(1); return
	print("PASS: Visual Hub metadata exported: %d records" % output.size())
	quit()
