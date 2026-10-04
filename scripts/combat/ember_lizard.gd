extends "res://scripts/combat/fire_pouch_lizard.gd"
func _init() -> void:
	spec = Spec.LIZARD.duplicate(true)
	spec.merge({"id":"ember_lizard","name":"熾火トカゲ","hp":4.2,"shots":7,"shot_interval":0.26},true)
func prepare(spawn: Vector2) -> void:
	super.prepare(spawn)
	modulate = Color.WHITE
	var palette := ShaderMaterial.new()
	palette.shader = preload("res://scripts/visuals/enemy_variant_palette.gdshader")
	palette.set_shader_parameter("iron",false)
	material = palette
func enemy_visual_snapshot() -> Dictionary:
	var view := super.enemy_visual_snapshot()
	view.enemy_id = "fire_pouch_lizard"
	return view
