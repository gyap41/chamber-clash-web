extends RefCounted
# Art is data: replace paths in assets/ui/hud/skin.json, never combat code.
const SKIN_PATH := "res://assets/ui/hud/skin.json"
static var skin: Dictionary = {}
static var textures: Dictionary = {}
static func optional_texture(key: String) -> Texture2D:
	# Initialize the shared skin without turning missing optional backgrounds into icons.
	texture("fallback")
	if not skin.has(key) or str(skin[key]).is_empty(): return null
	if not ResourceLoader.exists(str(skin[key])): return null
	return texture(key)
static func texture(key: String) -> Texture2D:
	if textures.has(key): return textures[key]
	if skin.is_empty():
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(SKIN_PATH))
		if parsed is Dictionary: skin = parsed
	var path: String = str(skin.get(key, skin.get("fallback", "")))
	if not ResourceLoader.exists(path): path = str(skin.get("fallback", ""))
	var art: Texture2D = load(path) if ResourceLoader.exists(path) else null
	textures[key] = art
	return art
