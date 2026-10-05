extends CanvasLayer
const Widgets = preload("res://scripts/ui/hud_widgets.gd")
const Description = preload("res://scripts/ui/item_description.gd")
const Items = preload("res://scripts/game/item_identity.gd")
const Grid = preload("res://scripts/game/build_grid.gd")
const Footprint = preload("res://scripts/ui/item_footprint.gd")
const ShopSkin = preload("res://scripts/ui/shop_skin.gd")
const Weapons = preload("res://scripts/catalog/weapon_catalog.gd")
const Relics = preload("res://scripts/catalog/relic_catalog.gd")
const Art = preload("res://scripts/ui/hud_assets.gd")
signal close_requested
signal purchase_requested
var game
var entry: Dictionary
var buy_button: Button
var reason_label: Label
var wallet: Label
var front
var animate_purchase: bool = false
var purchased: bool = false
var elapsed: float = 0
var purchase_elapsed: float = -1
var close_elapsed: float = -1
var panel: Control
func _ready() -> void:
	layer = 32
	var shade := ColorRect.new()
	shade.color = Color(0,0,0,.65)
	shade.size = Vector2(1120,800)
	add_child(shade)
	var back := ShopSkin.new()
	add_child(back)
	panel = Control.new()
	panel.name = "ShopDetail"
	add_child(panel)
	wallet = Widgets.label(panel,"Wallet",Rect2(815,192,100,32),20)
	wallet.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var title: String = entry.label
	var description := RichTextLabel.new()
	description.name = "Description"
	description.position = Vector2(496,316)
	description.size = Vector2(420,230)
	description.add_theme_font_size_override("normal_font_size",18)
	panel.add_child(description)
	front = ShopSkin.new()
	front.foreground = true
	if entry.kind in ["weapon","relic"]:
		var data: Dictionary = Weapons.definition(entry.item) if entry.kind == "weapon" else Relics.definition(entry.item)
		title = data.name
		var text: String = Description.describe(entry.kind,entry.item,game.exploration.inventory,true)
		text = text.substr(text.find("\n")+1)
		description.text = text.split("\n必要な面積：")[0].strip_edges()
		front.product = Weapons.pickup_art(entry.item) if entry.kind == "weapon" else Art.texture("relic_%02d" % entry.item)
		var token: Variant = Items.gun_token(entry.item) if entry.kind == "weapon" else Items.relic_token(entry.item,0)
		var footprint := Footprint.new()
		footprint.shape = Grid.shape_of(token)
		footprint.position = Vector2(284,487)
		footprint.size = Vector2(68,42)
		panel.add_child(footprint)
	elif entry.kind == "expansion":
		title = "バッグ拡張"
		description.text = "上限24マス\n\n次回の価格 %dG" % (int(entry.price)+2)
		for y in range(6):
			for x in range(6):
				var cell := Vector2i(x,y)
				var button := Widgets.button(panel,"Expand_%d_%d" % [x,y],Rect2(207+x*37,264+y*37,33,33),"",func():
					if purchased or close_elapsed>=0 or elapsed<1.3: return
					entry.cell = cell
					refresh())
				style_button(button)
	else:
		if entry.kind == "ammo": front.product = preload("res://assets/first-workshop/ammo.png")
		else: front.supply_kind = "heal"
		description.text = "HPを最大2回復します。最大HPは増えません。" if entry.kind == "heal" else "装備中の各武器に、予備弾薬の上限の40%を補給します。上限を超えません。控え・無限弾薬の武器は対象外です。"
	Widgets.label(panel,"Title",Rect2(496,245,420,48),26).text = title
	reason_label = Widgets.label(panel,"Reason",Rect2(380,557,234,74),15)
	reason_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	buy_button = Widgets.button(panel,"Buy",Rect2(624,578,280,62),"",request_purchase)
	style_button(buy_button)
	var close_button := Widgets.button(panel,"Close",Rect2(936,155,34,34),"×",request_close)
	style_button(close_button)
	add_child(front)
	refresh()
func style_button(button: Button) -> void:
	button.add_theme_font_size_override("font_size",18)
	for state in ["normal","hover","pressed","disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("294e43") if state != "disabled" else Color("29332f")
		if state == "hover": style.bg_color = Color("407461")
		if state == "pressed": style.bg_color = Color("153b30")
		style.border_color = Color("ab9866")
		style.set_border_width_all(1)
		style.set_corner_radius_all(6)
		button.add_theme_stylebox_override(state,style)
func request_purchase() -> void:
	if purchased or close_elapsed>=0 or elapsed<1.3 or buy_button.disabled: return
	animate_purchase = true
	purchase_requested.emit()
	animate_purchase = false
func purchase_complete() -> void:
	purchased = true
	purchase_elapsed = 0
	buy_button.disabled = true
	buy_button.text = "✓"
	reason_label.text = ""
	wallet.text = "%d G" % game.Events.gold(game)
	if entry.kind == "expansion": refresh()
func request_close() -> void:
	if close_elapsed>=0: return
	close_elapsed = 0
	buy_button.disabled = true
func _process(delta: float) -> void:
	elapsed += delta
	front.clock += delta
	front.time = minf(elapsed,1.3)
	if purchase_elapsed>=0:
		purchase_elapsed += delta
		front.purchase_time = purchase_elapsed
		if purchase_elapsed>=1.2: request_close()
	if close_elapsed>=0:
		close_elapsed += delta
		front.time = 1.3*(1-clampf(close_elapsed/.3,0,1))
		if close_elapsed>=.3:
			close_requested.emit()
			return
	front.queue_redraw()
func refresh() -> void:
	if entry.kind == "expansion":
		var usable: Dictionary = game.exploration.inventory.usable_cells(0)
		var available: Array = game.exploration.inventory.expansion_cells()
		for y in range(6):
			for x in range(6):
				var button: Button = get_node("ShopDetail/Expand_%d_%d" % [x,y])
				var cell := Vector2i(x,y)
				button.disabled = purchased or cell not in available
				button.text = "✓" if entry.cell == cell else ("■" if usable.has(cell) else ("+" if cell in available else ""))
	var reason: String = game.Events.purchase_reason(game,entry)
	wallet.text = "%d G" % game.Events.gold(game)
	buy_button.text = "✓" if purchased else "%s %d G" % ["拡張" if entry.kind == "expansion" else "購入",entry.price]
	buy_button.disabled = purchased or not reason.is_empty()
	reason_label.text = "" if purchased else reason
