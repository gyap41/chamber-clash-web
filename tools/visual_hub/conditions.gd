extends RefCounted
const DIRECTORY = "res://.local/visual-hub"
const SETTINGS = DIRECTORY+"/settings.json"
static func defaults() -> Dictionary:
	return {"page":0,"query":"","category":"キャラ","status":"すべて","sort":0,"selected":"character:0","compare":[],"screen":"単体","zoom":2.0,"fit":false,"background":"暗","aim":0,"movement":0,"action":"待機","sync":"実時間","speed":1.0,"time":0.0,"seed":719,"dt":1.0/60.0,"weapon":20,"icon":false,"camera":"俯瞰","movement_bounds":true,"bullet_bounds":true,"spawns":true,"supplies":true,"guides":true,"files":false,"playing":false,"scenario":"target"}
static func normalize(value: Dictionary) -> Dictionary:
	var result := defaults()
	for key in result:
		if value.has(key) and typeof(value[key]) == typeof(result[key]): result[key] = value[key]
		elif value.has(key) and (result[key] is int or result[key] is float) and (value[key] is int or value[key] is float): result[key] = value[key]
	result.zoom = clampf(result.zoom,.125,8)
	result.speed = clampf(result.speed,.1,4)
	result.time = clampf(result.time,0,30)
	result.dt = 1.0/120.0 if float(result.dt)<.012 else 1.0/60.0
	result.aim = clampi(int(result.aim),0,3); result.movement = clampi(int(result.movement),0,3)
	result.compare = result.compare.filter(func(id): return id is String).slice(0,4)
	return result
static func save(path: String, value: Dictionary) -> Error:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path,FileAccess.WRITE)
	if file == null: return FileAccess.get_open_error()
	file.store_string(JSON.stringify(value,"\t")); return OK
static func read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path): return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}
static func unique_path(extension: String) -> String:
	return DIRECTORY+"/capture-%d-%d.%s" % [int(Time.get_unix_time_from_system()),Time.get_ticks_usec(),extension]
