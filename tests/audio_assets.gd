extends SceneTree
# Resource import check only. Does not play audio or change the game.
func _init() -> void:
	var manifest = JSON.parse_string(FileAccess.get_file_as_string("res://assets/audio/asset_manifest.json"))
	if not manifest is Dictionary or not manifest.get("assets") is Array:
		printerr("FAIL: invalid audio manifest")
		quit(1)
		return
	if manifest.assets.is_empty():
		print("SKIP: no generated audio assets")
		quit(0)
		return
	for entry in manifest.assets:
		var path: String = entry.get("file_path", "")
		if not path.begins_with("res://assets/audio/") or not ResourceLoader.exists(path):
			printerr("FAIL: audio resource missing")
			quit(1)
			return
		var stream = load(path)
		if not stream is AudioStream or stream.get_length() <= 0:
			printerr("FAIL: audio stream invalid")
			quit(1)
			return
		print("PASS: ", path, " / ", stream.get_class(), " / ", stream.get_length(), " seconds")
	quit(0)
