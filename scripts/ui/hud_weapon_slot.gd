extends Button
const HudArt = preload("res://scripts/ui/exploration_hud_skin.gd")
const Weapons = preload("res://scripts/catalog/weapon_catalog.gd")
signal slot_requested(index: int)
var slot_index := 0
var compact: bool = false
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
	if compact:
		custom_minimum_size = Vector2(44,48)
		vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
		for key in ["normal","hover","pressed","disabled"]:
			var style := StyleBoxTexture.new()
			style.texture = HudArt.texture("socket")
			style.modulate_color = Color(1.15,1.3,1.2) if key == "hover" else Color.WHITE
			add_theme_stylebox_override(key,style)
func refresh(view: Dictionary) -> void:
	visible = slot_index < view.weapons.size()
	disabled = not visible or not view.can_switch
	if not visible: return
	var weapon: Dictionary = view.weapons[slot_index]
	icon = Weapons.art(weapon.id)
	text = str(slot_index+1)
	modulate = Color("ffc980") if view.selected == slot_index else Color("aebdc5")
	tooltip_text = "%s\n弾倉 %d / 予備 %s\n%s" % [weapon.name,weapon.clip,"∞" if weapon.get("infinite_reserve",false) else str(weapon.reserve),weapon.description]
	if not weapon.mod_name.is_empty(): tooltip_text += "\n改造："+weapon.mod_name
	if compact:
		text = ""
		icon = Weapons.pickup_art(weapon.id)
