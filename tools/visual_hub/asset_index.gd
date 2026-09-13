extends RefCounted
const Record = preload("res://tools/visual_hub/asset_record.gd")
const Catalog = preload("res://scripts/catalog/game_catalog.gd")
const Weapons = preload("res://scripts/catalog/weapon_catalog.gd")
const Relics = preload("res://scripts/catalog/relic_catalog.gd")
const Characters = preload("res://scripts/catalog/character_catalog.gd")
const Visuals = preload("res://scripts/catalog/weapon_visual_catalog.gd")
const Rig = preload("res://scripts/visuals/character_rig.gd")
var records: Array = []
var by_id: Dictionary = {}
var errors: Array = []
var fingerprint := ""
var changes := ""
var catalog: Dictionary = {}
var visuals: Dictionary = {}
var skin: Dictionary = {}
var static_users: Dictionary = {}
var file_records_loaded := false
var invalid_visuals := false
func read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		errors.append("JSON欠落: "+path)
		return {}
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK or not parser.data is Dictionary:
		errors.append("JSON不正: %s (line %d)" % [path,parser.get_error_line()])
		return {}
	return parser.data
func reload(catalog_path: String = "res://data/catalog.json", visual_path: String = "res://data/weapon_visuals.json", include_files: bool = false) -> void:
	var old := by_id.keys()
	records = []; by_id = {}; errors = []; static_users = {}
	catalog = read_json(catalog_path); visuals = read_json(visual_path)
	skin = read_json("res://assets/ui/hud/skin.json")
	invalid_visuals = false
	for key in ["weapons","families","effects","variants"]:
		if not visuals.get(key,{}) is Dictionary:
			errors.append("weapon_visuals: 不正な " + key); visuals[key] = {}; invalid_visuals = true
	for key in skin.keys():
		if not skin[key] is String:
			errors.append("skin: 不正な画像パス " + key); skin.erase(key)
	_scan_references()
	for pair in [["characters","キャラ","character"],["guns","武器","weapon"],["relics","レリック","relic"]]:
		var entries = catalog.get(pair[0],[])
		if not entries is Array:
			errors.append(pair[0]+": 配列が必要"); continue
		for entry in entries:
			if not entry is Dictionary or not entry.has("id") or not (entry.id is float or entry.id is int) or float(entry.id) != floor(float(entry.id)) or int(entry.id)<0:
				errors.append(pair[0]+": 不正なID/定義を隔離"); continue
			var item := Record.make(pair[2]+":"+str(int(entry.id)),str(entry.get("name","名前未定義")),pair[1])
			item.definition = entry.duplicate(true); item.defined = true
			Record.add_reference(item,catalog_path,"静的参照","%s / id=%d" % [pair[0],int(entry.id)])
			match pair[0]:
				"characters": _character(item)
				"guns": _weapon(item,visual_path)
				"relics": _relic(item)
			_add(item)
	for category in catalog:
		if category in ["characters","guns","relics"] or not catalog[category] is Array: continue
		for entry in catalog[category]:
			if not entry is Dictionary: continue
			var item := Record.make("unknown:"+category+":"+str(entry.get("id",records.size())),str(entry.get("name",category)),"その他定義","未確認")
			item.definition=entry.duplicate(true); item.defined=true
			item.image=str(entry.get("image",entry.get("texture","")))
			item.preview=not item.image.is_empty()
			item.issues.append("未知の種類: 基本情報と静止画像のみ。ゲーム対応は未確認")
			Record.add_reference(item,catalog_path,"静的参照",category)
			if not item.image.is_empty(): Record.add_reference(item,item.image,"静的参照","画像")
			_add(item)
	for key in skin:
		if key.begins_with("relic_") or key == "fallback": continue
		var item := Record.make("action:"+key,{"dodge":"回避","melee":"近接","pulse":"パルス"}.get(key,key),"行動アイコン")
		item.image = skin[key]; item.defined = true; item.game = key in ["dodge","melee","pulse"]
		Record.add_reference(item,"res://assets/ui/hud/skin.json","静的参照",key)
		Record.add_reference(item,item.image,"静的参照","UI画像・戦闘HUD 24px")
		Record.add_reference(item,"res://scripts/ui/hud.gd","コード生成","実UIサイズ・行動状態")
		item.preview = true; _add(item)
	for path in files("res://data/fields",["tres"]): _field(path)
	file_records_loaded = include_files
	if include_files: _file_records()
	var fresh := by_id.keys()
	changes = "追加 %d / 削除 %d" % [fresh.filter(func(id): return not old.has(id)).size(),old.filter(func(id): return not fresh.has(id)).size()]
	var revisions := {}
	for item in records:
		for ref in item.references:
			if FileAccess.file_exists(ref.path): revisions[ref.path]=FileAccess.get_modified_time(ref.path)
	fingerprint = (JSON.stringify(catalog)+JSON.stringify(visuals)+JSON.stringify(skin)+JSON.stringify(revisions)).sha256_text()
func _required(item: Dictionary, keys: Array) -> bool:
	var valid := true
	for key in keys:
		if not item.definition.has(key):
			item.issues.append("必須定義不足: "+key); valid = false
		elif key in ["hp","speed","reload","dodge","blanks","cell","gun","rate","damage","mag","stock"]:
			var value = item.definition[key]
			if not (value is int or value is float) or not is_finite(float(value)) or float(value)<0:
				item.issues.append("必須数値不正: "+key); valid = false
		elif not item.definition[key] is String:
			item.issues.append("必須文字列不正: "+key); valid = false
	return valid
func _character(item: Dictionary) -> void:
	var id := int(item.definition.id)
	var valid := _required(item,["name","hp","speed","reload","dodge","blanks","cell","gun"])
	item.game = id >= 0 and id < Rig.Directions.NAMES.size()
	item.method = "actor"
	if item.game:
		var base: String = "res://assets/first-workshop/rina-directions/" if id == 0 else "res://assets/first-workshop/directional-characters/"+Rig.Directions.NAMES[id]+"/"
		item.image = base+"front.png"
		for direction in ["front","back","side"]:
			for suffix in ["","-body","-foot-0","-foot-1"]: Record.add_reference(item,base+direction+suffix+".png","動的規則","CharacterRigのID→ディレクトリ・方向・パーツ")
			for stage in range(3):
				var path: String = "res://assets/first-workshop/rina-dodge/"+direction+"-"+str(stage)+".png" if id == 0 else base+direction+"-dodge-"+str(stage)+".png"
				Record.add_reference(item,path,"動的規則","3段階の回避。時間はPlayer、姿勢は実描画")
		if valid: item.related.append("weapon:"+str(int(item.definition.get("gun",-1))))
	for path in ["scenes/combat/player.tscn","scripts/combat/player.gd","scripts/visuals/player_animation.gd","scripts/visuals/character_rig.gd","scripts/visuals/rina_directions.gd" if id == 0 else "scripts/visuals/character_directions.gd"]:
		Record.add_reference(item,"res://"+path,"コード生成","待機・歩行・回避・装備")
	item.preview = item.game and valid and item.issues.is_empty()
	if not item.game: item.issues.append("プレビュー未対応: CharacterRigのID対応なし。JSON登録のみ")
func _weapon(item: Dictionary, path: String) -> void:
	var id := int(item.definition.id)
	var valid := _required(item,["name","rate","speed","damage","mag","stock","color","rarity"])
	_paths_in(item.definition,item,"動的規則","武器定義の追加Behavior参照")
	if not item.definition.get("behaviors",[]).is_empty(): item.issues.append("プレビュー未対応: 追加Behaviorの必要コンテキストをアダプターで確認・登録してください")
	item.game = Weapons.supported(id)
	item.method = "actor"
	var entry = visuals.get("weapons",{}).get(str(id),{})
	if not entry is Dictionary:
		item.issues.append("描画定義不正: weapons / "+str(id)); item.preview = false; return
	var family: String = str(entry.get("family",visuals.get("default_family","")))
	var family_data = visuals.get("families",{}).get(family,{})
	if not family_data is Dictionary:
		item.issues.append("描画系統不正: "+family); item.preview = false; return
	var profile: Dictionary = family_data.duplicate(true)
	profile.merge(entry,true)
	item["profile"] = profile
	if not profile.get("body",{}) is Dictionary:
		item.issues.append("body定義不正"); return
	if invalid_visuals: item.issues.append("描画JSONの構造不正")
	if profile.get("body",{}).is_empty() or str(profile.get("bullet","")).is_empty(): item.issues.append("fallback使用: body / bullet 未定義")
	for key in ["grip","muzzle","offset"]:
		if profile.get("body",{}).has(key) and not _vector_valid(profile.body[key]): item.issues.append("描画座標不正: "+key)
	if profile.has("bullet_size") and not _vector_valid(profile.bullet_size): item.issues.append("弾サイズ不正")
	item.image = str(profile.get("body",{}).get("texture",""))
	Record.add_reference(item,path,"静的参照","weapons / "+str(id)+" + family / "+family)
	if entry.is_empty() or not visuals.get("families",{}).has(family): item.issues.append("fallback使用: 武器プロファイル/系統が未登録")
	_paths_in(profile,item,"静的参照","武器描画プロファイル")
	for event in ["fire","hit","expire","split","reload_start","reload_complete"]:
		_paths_in(visuals.get("effects",{}).get(str(profile.get(event,"")),{}),item,"動的規則","演出イベント: "+event)
	for variant in [profile.get("fragment",""),profile.get("variant","")]:
		_paths_in(visuals.get("variants",{}).get(str(variant),{}),item,"動的規則","派生弾")
	for source in ["scripts/catalog/weapon_catalog.gd","scripts/catalog/weapon_visual_catalog.gd","scenes/combat/player.tscn","scripts/combat/player.gd","scripts/visuals/player_animation.gd","scripts/combat/combat_session.gd","scripts/combat/projectile.gd","scripts/visuals/projectile_art.gd","scripts/visuals/combat_visuals.gd","scripts/combat/weapon_behaviors.gd"]:
		Record.add_reference(item,"res://"+source,"コード生成","装備 / 発射 / 軌跡 / 着弾 / 派生の共通処理")
	if item.definition.get("gravity",false):
		for source in ["scripts/combat/gravity_well.gd","scripts/visuals/gravity_legendary.gd","assets/shaders/gravity_lens.gdshader"]: Record.add_reference(item,"res://"+source,"コード生成","重力場・CPU粒子・背景レンズ")
		Record.add_reference(item,str(visuals.get("gravity_core","")),"静的参照","重力核")
	item.preview = item.game and valid and item.issues.is_empty()
	if not item.game: item.issues.append("プレビュー未対応: WeaponCatalog.SUPPORTEDに登録なし。JSON登録だけではゲーム対応と判定しない")
func _vector_valid(value) -> bool:
	return value is Array and value.size()==2 and (value[0] is int or value[0] is float) and (value[1] is int or value[1] is float) and is_finite(float(value[0])) and is_finite(float(value[1]))
func _relic(item: Dictionary) -> void:
	var id := int(item.definition.id)
	item.game = Relics.supported(id)
	item.preview = true
	var key := "relic_%02d" % id
	item.image = str(skin.get(key,skin.get("fallback","")))
	if not skin.has(key): item.issues.append("fallback使用: skinに "+key+" がない")
	Record.add_reference(item,"res://assets/ui/hud/skin.json","静的参照",key)
	Record.add_reference(item,item.image,"静的参照","レリックアイコン")
	for source in ["scripts/catalog/relic_catalog.gd","scripts/combat/relic_effects.gd","scripts/ui/hud_assets.gd","scripts/ui/hud.gd"]: Record.add_reference(item,"res://"+source,"コード生成","使用・アイコン表示")
	if not item.game: item.issues.append("ゲーム未対応: RelicCatalog.SUPPORTEDに登録なし")
func _field(path: String) -> void:
	var field = ResourceLoader.load(path,"",ResourceLoader.CACHE_MODE_IGNORE)
	if field == null or not field.has_method("validation_errors"):
		errors.append("FieldDefinition読込失敗: "+path); return
	var item := Record.make("stage:"+field.field_id,field.field_id,"ステージ","テスト" if field.field_id == "validation" else "現行")
	item.definition = {"field_id":field.field_id,"path":path,"size":str(field.field_rect.size),"actors":"編成はScene/Roster側。配置定義に含めない"}
	item.defined = true; item.game = true; item.method = "stage"
	Record.add_reference(item,path,"静的参照","FieldDefinition・配置原本")
	for scene in static_users.get(path,[]): Record.add_reference(item,scene,"静的参照","FieldDefinitionを使用するScene。Actor編成は別情報")
	for source in ["scripts/world/field_builder.gd","scripts/world/arena.gd","scenes/world/wall.tscn","scripts/visuals/workshop_floor.gd"]: Record.add_reference(item,"res://"+source,"コード生成","定義から床・壁・Spawn・補給候補を構築")
	item.issues.append_array(Array(field.validation_errors()))
	item.preview = item.issues.is_empty(); _add(item)
func _add(item: Dictionary) -> void:
	if by_id.has(item.id):
		errors.append("重複IDを隔離: "+item.id); return
	item.assets = not item.image.is_empty() and FileAccess.file_exists(item.image)
	if item.method == "stage": item.assets = item.issues.is_empty()
	for ref in item.references:
		if ref.path.get_extension() in ["png","svg"] and FileAccess.file_exists(ref.path) and not ref.path.begins_with("res://docs/") and not ref.path.begins_with("res://assets/generated/"):
			if not ResourceLoader.exists(ref.path):
				item.issues.append("未インポート: "+ref.path)
	if item.method == "actor" and not item.issues.is_empty(): item.preview = false
	if not item.image.is_empty() and not item.assets: item.issues.append("画像欠落: "+item.image)
	for reference in item.references:
		for source in static_users.get(reference.path,[]):
			if not item.users.has(source): item.users.append(source)
	if item.users.is_empty(): item["usage_note"] = "静的参照未検出。動的規則・テスト利用の可能性があり、未使用とは確定しない"
	by_id[item.id] = item; records.append(item)
func _paths_in(value, item: Dictionary, relation: String, reason: String) -> void:
	if value is Dictionary:
		for child in value.values(): _paths_in(child,item,relation,reason)
	elif value is Array:
		for child in value: _paths_in(child,item,relation,reason)
	elif value is String and value.begins_with("res://"): Record.add_reference(item,value,relation,reason)
func files(root: String, extensions: Array) -> Array:
	var result: Array = []
	var dir := DirAccess.open(root)
	if dir == null: return result
	for name in dir.get_files():
		if name.get_extension().to_lower() in extensions: result.append(root.path_join(name))
	for name in dir.get_directories():
		if name.begins_with(".") or name in ["web-build","node_modules","legacy-web"] or FileAccess.file_exists(root.path_join(name).path_join("project.godot")): continue
		result.append_array(files(root.path_join(name),extensions))
	return result
func _scan_references() -> void:
	var regex := RegEx.new(); regex.compile('res://[^"\\s\\)\\],;]+')
	for root in ["res://scripts","res://scenes","res://data","res://tests"]:
		for path in files(root,["gd","tscn","tres","json"]):
			for hit in regex.search_all(FileAccess.get_file_as_string(path)):
				var target := hit.get_string().trim_suffix("'")
				if FileAccess.file_exists(target):
					if not static_users.has(target): static_users[target] = []
					if not static_users[target].has(path): static_users[target].append(path)
func _file_records() -> void:
	var linked: Dictionary = {}
	for item in records:
		for ref in item.references: linked[ref.path] = true
	for root in ["res://assets","res://docs","res://tests/fixtures"]:
		for path in files(root,["png","svg","gif","wav","mp3","gdshader","ttf"]):
			var status := "補助参照" if linked.has(path) or static_users.has(path) else "未確認"
			if path.begins_with("res://docs/"): status = "履歴" if "/archive/" in path or "/reviews/" in path else "原画・制作"
			if "/generated/" in path or "/reference/" in path: status = "原画・制作"
			if path.begins_with("res://tests/"): status = "テスト"
			var item := Record.make("file:"+path.trim_prefix("res://"),path.get_file(),"素材ファイル",status)
			if path.get_extension() in ["png","svg"]: item.image = path; item.preview = true
			else: item.issues.append("静止画像プレビュー未対応: "+path.get_extension()+"（基本情報のみ）")
			Record.add_reference(item,path,"ファイル","ファイル実体。現行カタログの件数とは別集計")
			_add(item)
func detail(id: String) -> Dictionary: return by_id.get(id,{})
func enumerate(query: String = "", kind: String = "すべて", status: String = "すべて") -> Array:
	return records.filter(func(item): return Record.matches(item,query,kind,status))
# Safe snapshot install only inside the standalone Hub process, after old previews terminate.
func install_game_snapshot() -> void:
	var safe: Dictionary = {"guns":[],"relics":[],"characters":[]}
	for item in records:
		var category: String = {"武器":"guns","キャラ":"characters","レリック":"relics"}.get(item.kind,"")
		if not category.is_empty() and (item.preview or item.kind == "レリック"): safe[category].append(item.definition.duplicate(true))
	Catalog.data = safe; Catalog.indexes.clear()
	if visuals.has("weapons") and visuals.has("families") and visuals.has("default_family") and visuals.families.has(visuals.default_family):
		var snapshot := visuals.duplicate(true)
		snapshot.weapons = {}
		for item in records:
			if item.kind == "武器" and item.preview: snapshot.weapons[str(int(item.definition.id))] = visuals.weapons[str(int(item.definition.id))].duplicate(true)
		Visuals.data = snapshot
	Visuals.textures.clear(); Visuals.body_materials.clear()
	Weapons.textures.clear(); Characters.textures.clear()
	Weapons.EQUIPMENT_SCALE = Visuals.body_scales(); Weapons.EQUIPMENT_POINTS = Visuals.body_points()
	preload("res://scripts/ui/hud_assets.gd").skin = skin.duplicate(true)
	preload("res://scripts/ui/hud_assets.gd").textures.clear()
	Rig.Directions.cache.clear(); Rig.RinaDirections.textures.clear(); Rig.RinaDirections.Dodge.textures.clear()
