extends Panel
# P8 配置基盤：グリッドの1マス。ドロップされたもの（P8z以降はレリックだけでなく武器も）が、
# このマスを基準マスとして自分の形状ぶんすべて空いている場合のみ受け入れる
# （判定自体はmatch_state.fits()に委譲、当たり判定ロジックの重複を避ける）。
# 子にRelicChipを乗せる／乗せないのはpreparation.gd側の責務（このスクリプトは当たり判定と
# 委譲のみ）。
var game
var player_index := 0
var cell := Vector2i.ZERO
var on_drop: Callable
var on_click: Callable
var preview_color := Color.TRANSPARENT
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and on_click.is_valid():
		on_click.call(cell)
		accept_event()
func _draw() -> void:
	if preview_color.a > 0:
		draw_rect(Rect2(Vector2(2,2),size-Vector2(4,4)),preview_color,false,3)
func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if typeof(data) != TYPE_DICTIONARY or not data.has("entry"): return false
	if data.entry not in game.match_state.builds[player_index].owned: return false
	return game.match_state.fits(player_index,data.entry,cell-data.get("grab_offset",Vector2i.ZERO),data.entry)
func _drop_data(_at_position: Vector2, data: Variant) -> void:
	on_drop.call(data.entry,cell-data.get("grab_offset",Vector2i.ZERO))
