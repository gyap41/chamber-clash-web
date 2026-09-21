extends Button
const Weapons = preload("res://scripts/catalog/weapon_catalog.gd")
signal slot_requested(index: int)
var slot_index := 0
func _ready() -> void:
	custom_minimum_size = Vector2(44,56)
	focus_mode = Control.FOCUS_NONE
	mouse_filter = Control.MOUSE_FILTER_STOP
	expand_icon = true
	icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	add_theme_constant_override("icon_max_width",30)
	add_theme_font_size_override("font_size",12)
	pressed.connect(func():
		if not disabled: slot_requested.emit(slot_index))
func refresh(view: Dictionary) -> void:
	visible = slot_index < view.weapons.size()
	disabled = not visible or not view.can_switch
	if not visible: return
	var weapon: Dictionary = view.weapons[slot_index]
	icon = Weapons.art(weapon.id)
	text = str(slot_index+1)
	modulate = Color("ffc980") if view.selected == slot_index else Color("aebdc5")
	tooltip_text = "%s\n弾倉 %d / 予備 %d\n%s" % [weapon.name,weapon.clip,weapon.reserve,weapon.description]
	if not weapon.mod_name.is_empty(): tooltip_text += "\n改造："+weapon.mod_name
