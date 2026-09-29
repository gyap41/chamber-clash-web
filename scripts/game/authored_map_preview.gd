extends "res://scripts/game/exploration.gd"
const AuthoredFloor = preload("res://scripts/game/authored_floor.gd")
var generated_floor: Dictionary
var seed_label: Label
var preview_seed := 0

func _ready() -> void:
	get_window().title = "CHAMBER CLASH - Authored Random Map"
	encounters_enabled = false
	preserve_room_dressing = true
	super._ready()
	var panel := PanelContainer.new()
	panel.position = Vector2(18,96)
	get_node("HUD").add_child(panel)
	var bar := HBoxContainer.new()
	panel.add_child(bar)
	seed_label = Label.new()
	bar.add_child(seed_label)
	var regenerate := Button.new()
	regenerate.text = "別のマップ"
	regenerate.focus_mode = Control.FOCUS_NONE
	regenerate.pressed.connect(func(): start_exploration(preview_seed+1))
	bar.add_child(regenerate)
	var gallery := Button.new()
	gallery.text = "20室一覧へ"
	gallery.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/game/authored_rooms_preview.tscn"))
	bar.add_child(gallery)
	update_seed_label()

func start_exploration(seed_value: int) -> void:
	preview_seed = seed_value
	generated_floor = AuthoredFloor.generate(seed_value)
	if not generated_floor.errors.is_empty():
		push_error(str(generated_floor.errors))
		return
	# Keep semantic generation roles for validation, while disabling boss/reward progression in this art tour.
	floor_data = generated_floor.duplicate(true)
	floor_data.preview = true
	for meta in floor_data.rooms.values():
		meta.map_label = {"normal":"通路","start":"入口","discovery":"寄り道","antechamber":"前室","boss":"最奥"}[meta.role]
		meta.role = "start" if meta.role == "start" else "normal"
	room_catalog = generated_floor.catalog
	start_room = generated_floor.start
	random_floor = false
	super.start_exploration(seed_value)
	update_seed_label()

func update_seed_label() -> void:
	if seed_label != null:
		seed_label.text = " seed %d  / %d室  / 敵なし・箱は美術見本  / M：地図  " % [preview_seed,room_catalog.size()]

func rebuild_supplies() -> void:
	# Room art review has no gameplay pickups, including the usual entry-room supply kit.
	pass

func room_loot() -> Array:
	return []

func try_supply() -> bool:
	return false
