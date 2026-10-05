extends Control
const Widgets = preload("res://scripts/ui/hud_widgets.gd")
const Weapons = preload("res://scripts/catalog/weapon_catalog.gd")
var displayed_weapon := -2
var compact: bool = false
var energy_time: float = 0.0
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	Widgets.label(self,"Name",Rect2(0,0,214,21),15)
	Widgets.label(self,"Ammo",Rect2(46,22,168,35),24).tooltip_text = "装弾数 / 予備弾数"
	Widgets.label(self,"State",Rect2(0,60,214,18),12)
	var art := TextureRect.new()
	art.name = "Art"
	art.position = Vector2(0,25)
	art.size = Vector2(40,28)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(art)
	var progress := ProgressBar.new()
	progress.name = "Reload"
	progress.position = Vector2(0,57)
	progress.size = Vector2(210,4)
	progress.show_percentage = false
	progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(progress)
	if compact:
		size = Vector2(296,86)
		$Name.hide()
		$State.hide()
		$Art.position = Vector2(14,12)
		$Art.size = Vector2(99,58)
		$Ammo.position = Vector2(127,17)
		$Ammo.size = Vector2(154,40)
		$Ammo.add_theme_font_size_override("font_size",28)
		$Reload.position = Vector2(127,62)
		$Reload.size = Vector2(146,5)
		var fill := StyleBoxFlat.new()
		fill.bg_color = Color("87d8bd")
		var background := StyleBoxFlat.new()
		background.bg_color = Color("163b3d")
		$Reload.add_theme_stylebox_override("fill",fill)
		$Reload.add_theme_stylebox_override("background",background)
func _process(delta: float) -> void:
	if not compact: return
	if $Reload.visible or energy_time > 0:
		energy_time = energy_time+delta if $Reload.visible else 0.0
		queue_redraw()
func _draw() -> void:
	if not compact or energy_time <= 0: return
	# 2026-10-06: one restrained moving spark along the loading conduit.
	var x: float = 127+fmod(energy_time*130,136)
	draw_line(Vector2(x,73),Vector2(minf(x+10,273),73),Color("b5ffe2"),2,true)
func refresh(view: Dictionary) -> void:
	var armed: bool = view.selected >= 0 and view.selected < view.weapons.size()
	var weapon: Dictionary = view.weapons[view.selected] if armed else {}
	var id: int = weapon.id if armed else -1
	$Name.text = view.weapon_name
	if id != displayed_weapon:
		displayed_weapon = id
		$Art.texture = Weapons.art(id) if armed else null
		$Art.material = Weapons.Visuals.body_material(id,Vector2(40,28)) if armed else null
	$Ammo.text = "%d · 予備%s" % [weapon.clip,"∞" if weapon.get("infinite_reserve",false) else str(weapon.reserve)] if armed else "丸腰"
	var wait: float = view.reload
	$Reload.visible = wait > 0
	$Reload.value = clampf(1.0-wait/maxf(view.reload_duration,wait),0.0,1.0)*100 if wait > 0 else 0
	$State.text = "装填中 %.1f秒" % wait if wait > 0 else ("R 装填  ·  E / ホイール 切替" if armed else "近接攻撃で戦えます")
	if compact:
		$Ammo.text = "%d / %s" % [weapon.clip,"∞" if weapon.get("infinite_reserve",false) else str(weapon.reserve)] if armed else "丸腰"
		$Art.texture = Weapons.pickup_art(id) if armed else null
		$Art.material = null
