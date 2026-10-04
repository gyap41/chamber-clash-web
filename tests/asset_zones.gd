extends SceneTree
# 未採用の候補（assets/candidates）と不採用・旧版（assets/retired）を、ゲームが参照していないことを確かめる。
# 例外は開発用プレビューのAutoloadだけ。台帳・説明文は参照ではないので対象外。
const ZONES := ["assets/candidates/", "assets/retired/"]
const SCAN_ROOTS := ["res://scripts", "res://scenes", "res://data", "res://assets"]
const EXTENSIONS := ["gd", "tscn", "tres", "json", "cfg", "gdshader"]
const ALLOWED := ["res://scripts/dev/candidate_preview.gd"]
const SKIP_DIRS := ["res://assets/candidates", "res://assets/retired", "res://assets/generated", "res://assets/reference"]
# 全画像・全音源を列挙する台帳。ゲームからは読み込まない。
const LEDGERS := ["res://assets/graphics_inventory.json", "res://assets/audio/asset_manifest.json"]

var offenders: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var uids: Array[String] = candidate_uids("res://assets/candidates")
	var files: Array[String] = []
	for scan_root in SCAN_ROOTS:
		collect(scan_root, files)
	files.append("res://project.godot")
	for path in files:
		if path in ALLOWED or path in LEDGERS:
			continue
		var text: String = FileAccess.get_file_as_string(path)
		for zone in ZONES:
			if text.contains(zone):
				offenders.append("%s → %s" % [path, zone])
		for uid in uids:
			if text.contains(uid):
				offenders.append("%s → %s" % [path, uid])
	for entry in offenders:
		print("FAIL: 候補・旧版素材への参照: ", entry)
	assert(offenders.is_empty())
	# 旧版はインポートしない。候補は試せるようにインポートするが、どちらも書き出しから除外する。
	assert(FileAccess.file_exists("res://assets/retired/.gdignore"))
	assert(not FileAccess.file_exists("res://assets/candidates/.gdignore"))
	var presets: String = FileAccess.get_file_as_string("res://export_presets.cfg")
	assert(presets.contains("assets/candidates/*") and presets.contains("assets/retired/*"))
	# プレビューは他のAutoloadより先に読み込まれないと、preload済みの素材を差し替えられない。
	var project: String = FileAccess.get_file_as_string("res://project.godot")
	var section: String = project.substr(project.find("[autoload]"))
	var first_entry: String = section.split("\n", false)[1]
	assert(first_entry.begins_with("CandidatePreview="))
	print("PASS: game data never references candidate/retired assets (%d files, %d candidate uids)" % [files.size(), uids.size()])
	quit()

func collect(dir_path: String, out: Array[String]) -> void:
	if dir_path in SKIP_DIRS:
		return
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	for sub in dir.get_directories():
		collect(dir_path.path_join(sub), out)
	for file in dir.get_files():
		if file.get_extension() in EXTENSIONS:
			out.append(dir_path.path_join(file))

# 候補をUID（uid://…）で参照しても検出できるよう、候補の.import/.uidからUIDを集める。
func candidate_uids(dir_path: String) -> Array[String]:
	var result: Array[String] = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return result
	for sub in dir.get_directories():
		result.append_array(candidate_uids(dir_path.path_join(sub)))
	for file in dir.get_files():
		if file.ends_with(".import") or file.ends_with(".uid"):
			for line in FileAccess.get_file_as_string(dir_path.path_join(file)).split("\n"):
				var at: int = line.find("uid://")
				if at >= 0:
					result.append(line.substr(at).get_slice("\"", 0).strip_edges())
	return result
