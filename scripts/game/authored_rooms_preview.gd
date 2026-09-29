extends "res://scripts/game/exploration.gd"
# Walk-through of the hand-authored room trial (docs/art/production/authored-rooms). No enemies.
const Authored = preload("res://scripts/world/authored_rooms.gd")
var room_picker: OptionButton
func _ready() -> void:
	get_window().title = "CHAMBER CLASH - 20 Rooms Preview"
	room_catalog = Authored.catalog()
	start_room = "collapsed_gallery"
	encounters_enabled = false
	preserve_room_dressing = true
	super._ready()
	# Preview-only room navigation: keep the real doors, and allow direct selection for a twenty-room review.
	var panel := PanelContainer.new()
	panel.position = Vector2(18,96)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(.06,.09,.10,.94)
	style.content_margin_left = 8
	style.content_margin_right = 8
	panel.add_theme_stylebox_override("panel",style)
	get_node("HUD").add_child(panel)
	var bar := HBoxContainer.new()
	panel.add_child(bar)
	room_picker = OptionButton.new()
	room_picker.custom_minimum_size = Vector2(300,36)
	room_picker.focus_mode = Control.FOCUS_NONE
	for i in range(Authored.ORDER.size()):
		room_picker.add_item("%02d  %s" % [i+1,Authored.NAMES[Authored.ORDER[i]]])
	room_picker.item_selected.connect(select_preview_room)
	bar.add_child(room_picker)
	var map_button := Button.new()
	map_button.text = "ランダムマップ"
	map_button.focus_mode = Control.FOCUS_NONE
	map_button.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/game/authored_map_preview.tscn"))
	bar.add_child(map_button)
	var help := Label.new()
	help.add_theme_font_size_override("font_size",14)
	help.text = "  敵なし / 扉：F / 箱は美術見本"
	bar.add_child(help)

func select_preview_room(index: int) -> void:
	if index < 0 or index >= Authored.ORDER.size(): return
	start_room = Authored.ORDER[index]
	start_exploration(1)

func refresh_hud() -> void:
	super.refresh_hud()
	if room_picker != null and exploration != null:
		room_picker.select(Authored.ORDER.find(exploration.room_id))
