extends Node
## 未採用の候補素材をゲーム内で試すための開発用Autoload。
## 起動引数 `-- --preview-candidate=<asset_id>/<version>`（複数指定可）のときだけ動き、
## assets/candidates/<asset_id>/<version>/preview.json の "replaces" に書いた使用中素材を
## Resource.take_over_path() で候補に差し替える。ファイルは一切変更しない。
## Godotは全Autoloadのスクリプトを先に読み込み（このときpreloadが確定する）、その後でインスタンスを作る。
## そのため差し替えはインスタンスの_init()ではなく、このスクリプトの読み込み時（static変数の初期化）に行う。
## project.godotのAutoload一覧の先頭に置くこと（tests/asset_zones.gdが確認する）。
## 書き出したゲーム（template）では何もしない。手順は assets/candidates/README.md。

const ARG_PREFIX := "--preview-candidate="
const ROOT := "res://assets/candidates/"

static var active: Array[String] = []
static var replaced: Array[String] = []
static var errors: Array[String] = []
# テストで意図的に失敗させるときは偽にし、push_error()を出さない（run_tests.ps1がERROR行をFAILと判定するため）。
static var report_errors := true
# take_over_path()後のResourceCacheは弱参照なので、候補を保持し続ける。
static var _keep: Array[Resource] = []
static var _booted: bool = _boot()

static func _boot() -> bool:
	if OS.has_feature("template"):
		return false
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with(ARG_PREFIX):
			var id: String = argument.substr(ARG_PREFIX.length())
			active.append(id)
			apply_folder(ROOT + id)
	return true

func _ready() -> void:
	if active.is_empty():
		return
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	var label := Label.new()
	label.position = Vector2(8, 776)
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color("#ffd54a") if errors.is_empty() else Color("#ff6b6b"))
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	var text: String = "候補プレビュー中: %s（差し替え%d件）" % [", ".join(active), replaced.size()]
	if not errors.is_empty():
		text += "  エラー%d件: %s" % [errors.size(), errors[0]]
	label.text = text
	layer.add_child(label)
	print("CandidatePreview: ", text)

## preview.jsonを読み、使用中のパスを候補へ差し替える。テストからも呼ぶ。
static func apply_folder(folder: String) -> void:
	var manifest_path: String = folder.path_join("preview.json")
	if not FileAccess.file_exists(manifest_path):
		_fail("preview.jsonがありません: " + manifest_path)
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	if typeof(parsed) != TYPE_DICTIONARY or typeof(parsed.get("replaces")) != TYPE_DICTIONARY:
		_fail("preview.jsonに replaces の辞書がありません: " + manifest_path)
		return
	var replaces: Dictionary = parsed.replaces
	for original in replaces:
		var source: String = str(replaces[original])
		var candidate_path: String = source if source.begins_with("res://") else folder.path_join(source)
		replace(str(original), candidate_path)
	# New cutout rigs have no existing bitmap path to replace. Explicit preview only.
	var machines: Variant = parsed.get("machine_sheets",{})
	if typeof(machines) != TYPE_DICTIONARY:
		_fail("machine_sheets must be a dictionary")
		return
	var visual = preload("res://scripts/visuals/remaining_machine_visual.gd")
	for id in machines:
		var entry: Variant = machines[id]
		if id not in visual.IDS or typeof(entry) != TYPE_DICTIONARY:
			_fail("Unknown machine sheet")
			continue
		var path: String = folder.path_join(str(entry.get("file","")))
		var rows: Array = entry.get("rows",[])
		if not ResourceLoader.exists(path) or rows.size() != 4:
			_fail("Missing machine texture or four row boundaries")
			continue
		var texture: Texture2D = load(path) as Texture2D
		if texture == null or rows[0] != 0 or rows[3] != texture.get_height() or rows[1] <= 0 or rows[2] <= rows[1] or rows[3] <= rows[2]:
			_fail("Invalid machine sheet bounds")
			continue
		visual.register_sheet(str(id),texture,rows,entry.get("regions",[]))
		replaced.append("machine:"+str(id))

static func replace(original: String, candidate_path: String) -> void:
	if not ResourceLoader.exists(original):
		_fail("差し替え先が存在しません: " + original)
		return
	if not ResourceLoader.exists(candidate_path):
		_fail("候補が読み込めません（未インポート？）: " + candidate_path)
		return
	var current: Resource = load(original)
	var candidate: Resource = load(candidate_path)
	if candidate.get_class() != current.get_class() and not (candidate is Texture2D and current is Texture2D) and not (candidate is AudioStream and current is AudioStream):
		_fail("種類が違います: %s(%s) ← %s(%s)" % [original, current.get_class(), candidate_path, candidate.get_class()])
		return
	if report_errors and candidate is Texture2D and (candidate as Texture2D).get_size() != (current as Texture2D).get_size():
		# 格子や切り出し座標をコードが持つ素材では位置がずれる。止めずに警告だけ出す。
		push_warning("CandidatePreview: 画像サイズが違います %s %s ← %s %s" % [original, (current as Texture2D).get_size(), candidate_path, (candidate as Texture2D).get_size()])
	candidate.take_over_path(original)
	_keep.append(candidate)
	replaced.append(original)

## テスト用。記録を消す（差し替え済みのキャッシュは保持した候補を解放すると元に戻る）。
static func reset() -> void:
	replaced.clear()
	errors.clear()
	_keep.clear()

static func _fail(message: String) -> void:
	errors.append(message)
	if report_errors:
		push_error("CandidatePreview: " + message)
