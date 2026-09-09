extends RefCounted
var file: FileAccess
var peak_shots := 0
var frames := 0
var frame_total := 0.0
func _init(seed_value: int) -> void:
	DirAccess.make_dir_recursive_absolute("user://run-logs")
	file = FileAccess.open("user://run-logs/run-%d-%d.jsonl" % [Time.get_unix_time_from_system(),Time.get_ticks_usec()],FileAccess.WRITE)
	record("seed",{"seed":seed_value})
func record(kind: String, data: Dictionary = {}) -> void:
	if file == null: return
	var event := data.duplicate(true)
	event["event"] = kind
	event["ms"] = Time.get_ticks_msec()
	file.store_line(JSON.stringify(event))
	if kind not in ["projectile","damage"]: file.flush()
func frame(dt: float, count: int) -> void:
	frames += 1
	frame_total += dt
	peak_shots = maxi(peak_shots,count)
	if frames % 60 == 0:
		record("performance",{"frame_ms":frame_total*1000.0/60,"max_projectiles":peak_shots})
		frame_total = 0.0
