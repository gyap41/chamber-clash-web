extends "res://scripts/combat/quillback.gd"
func _init() -> void:
	spec = Spec.QUILLBACK.duplicate(true)
	spec.merge({"id":"iron_quill","name":"鉄棘ヤマアラシ","hp":4.6,"shots":3,"recovery":1.35},true)
func prepare(spawn: Vector2) -> void:
	super.prepare(spawn)
	modulate = Color.WHITE
	var palette := ShaderMaterial.new()
	palette.shader = preload("res://scripts/visuals/enemy_variant_palette.gdshader")
	palette.set_shader_parameter("iron",true)
	material = palette
func enemy_visual_snapshot() -> Dictionary:
	var view := super.enemy_visual_snapshot()
	view.enemy_id = "quillback"
	return view
