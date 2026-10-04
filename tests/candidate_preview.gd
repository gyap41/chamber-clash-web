extends SceneTree
const Preview = preload("res://scripts/dev/candidate_preview.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	# 起動引数なしでは何も差し替えない。
	assert(root.has_node("CandidatePreview"))
	assert(Preview.active.is_empty() and Preview.replaced.is_empty() and Preview.errors.is_empty())
	var texture_path := "res://assets/first-workshop/ammo.png"
	var sound_path := "res://assets/audio/se/fw_enemy_defeat_01.mp3"
	# 寸法違いの警告は出す必要がないので抑える（fixtureは別寸法の既存画像を使う）。
	Preview.report_errors = false
	Preview.apply_folder("res://tests/fixtures/candidate_preview/v1")
	assert(Preview.errors.is_empty())
	assert(Preview.replaced.size() == 2)
	# load()・UID・preloadのどれで読んでも候補が返る。
	var candidate: Texture2D = load(texture_path)
	assert(candidate.resource_path == texture_path)
	assert(candidate == Preview._keep[0])
	var uid: String = ResourceUID.id_to_text(ResourceLoader.get_resource_uid(texture_path))
	assert(ResourceLoader.load(uid) == candidate)
	var script := GDScript.new()
	script.source_code = "extends RefCounted\nconst T = preload(\"%s\")\n" % texture_path
	assert(script.reload() == OK)
	assert(script.get_script_constant_map()["T"] == candidate)
	assert(load(sound_path) == Preview._keep[1])
	# 存在しない差し替え先・候補・preview.jsonはエラーとして記録し、止まらない。
	Preview.reset()
	Preview.replace("res://assets/nope/missing.png", "res://assets/first-workshop/bullet.png")
	Preview.replace(texture_path, "res://assets/candidates/nope/v1/missing.png")
	Preview.apply_folder("res://tests/fixtures/candidate_preview/missing")
	assert(Preview.errors.size() == 3 and Preview.replaced.is_empty())
	Preview.reset()
	Preview.report_errors = true
	print("PASS: candidate preview redirects load/uid/preload/audio and reports bad entries")
	quit()
