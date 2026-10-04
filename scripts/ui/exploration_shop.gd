extends CanvasLayer
const Widgets = preload("res://scripts/ui/hud_widgets.gd")
const Description = preload("res://scripts/ui/item_description.gd")
const Items = preload("res://scripts/game/item_identity.gd")
const Grid = preload("res://scripts/game/build_grid.gd")
const Footprint = preload("res://scripts/ui/item_footprint.gd")
signal close_requested
signal purchase_requested
var game
var entry: Dictionary
var buy_button: Button
var reason_label: Label
func _ready() -> void:
	layer = 32
	var shade := ColorRect.new()
	shade.color = Color(0,0,0,.65)
	shade.size = Vector2(1120,800)
	add_child(shade)
	var panel := Widgets.box(self,"ShopDetail",Rect2(220,115,680,560))
	Widgets.label(panel,"Title",Rect2(28,20,620,32),24).text = "露店 ／ 商品を確認"
	var description := Widgets.label(panel,"Description",Rect2(28,68,620,300),18)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if entry.kind in ["weapon","relic"]:
		description.text = Description.describe(entry.kind,entry.item,game.exploration.inventory,true)
		var token = Items.gun_token(entry.item) if entry.kind == "weapon" else Items.relic_token(entry.item,0)
		var footprint := Footprint.new()
		footprint.shape = Grid.shape_of(token)
		footprint.position = Vector2(28,377)
		footprint.size = Vector2(125,65)
		panel.add_child(footprint)
	elif entry.kind == "expansion":
		description.text = "バッグを1マス拡張\n既存マスに隣接した場所を選んで購入します。上限24マス。\n次の購入価格は2Gずつ上がります。"
		var usable: Dictionary = game.exploration.inventory.usable_cells(0)
		var available: Array = game.exploration.inventory.expansion_cells()
		for y in range(6):
			for x in range(6):
				var cell := Vector2i(x,y)
				var button := Widgets.button(panel,"Expand_%d_%d" % [x,y],Rect2(28+x*40,185+y*30,36,26),"■" if usable.has(cell) else "+",func():
					entry.cell = cell
					refresh())
				button.disabled = cell not in available
	else:
		description.text = "回復薬\nHPを最大2回復します。最大HPは増えません。" if entry.kind == "heal" else "弾薬補給\n装備中の各武器に、予備弾薬の上限の40%を補給します。上限を超えません。控え・無限弾薬の武器は対象外です。"
	reason_label = Widgets.label(panel,"Reason",Rect2(175,375,475,80),16)
	reason_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	buy_button = Widgets.button(panel,"Buy",Rect2(28,480,375,48),"",func(): purchase_requested.emit())
	Widgets.button(panel,"Close",Rect2(425,480,225,48),"戻る ／ Esc",func(): close_requested.emit())
	refresh()
func refresh() -> void:
	if entry.kind == "expansion":
		for y in range(6):
			for x in range(6):
				var button: Button = get_node("ShopDetail/Expand_%d_%d" % [x,y])
				var chosen: bool = entry.cell == Vector2i(x,y)
				button.modulate = Color("ffd35a") if chosen else Color.WHITE
				button.text = "✓" if chosen else ("■" if game.exploration.inventory.usable_cells(0).has(Vector2i(x,y)) else ("·" if button.disabled else "+"))
	var reason: String = game.Events.purchase_reason(game,entry)
	buy_button.text = "%dGで購入（所持 %dG）" % [entry.price,game.Events.gold(game)]
	buy_button.disabled = not reason.is_empty()
	reason_label.text = reason if not reason.is_empty() else ("購入すると控えへ入ります。\nTabでバッグに配置して使用。" if entry.kind in ["weapon","relic"] else "購入すると、その場で使用します。")
	if entry.kind == "expansion" and reason.is_empty(): reason_label.text = "選択：%d列・%d行\n購入時に1マス開放します。" % [entry.cell.x+1,entry.cell.y+1]
