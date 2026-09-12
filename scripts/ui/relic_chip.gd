extends Button
# P8 配置基盤：所持レリックをグリッド／控えへドラッグするための「つまみ」。クリックには何も
# 割り当てない（着脱・移動はドロップ側 [relic_grid_cell.gd / relic_tray.gd] が処理する）。
# P8z 装備モデルの統合：つまみが運ぶのは「所持庫の要素」——レリックは素のint、武器は
# "gun:<id>"の文字列トークン（match_state.gd冒頭参照）。以前のrelic_id（int固定）を一般化した。
var entry = -1
var grab_offset := Vector2i.ZERO
var on_drag_start: Callable
var on_reserve_drop: Callable
func _get_drag_data(_at_position: Vector2) -> Variant:
	if on_drag_start.is_valid(): on_drag_start.call(entry)
	var preview := Button.new()
	preview.text = tooltip_text.get_slice("\n",0) if text.is_empty() else text
	preview.custom_minimum_size = custom_minimum_size
	preview.modulate.a = .7
	set_drag_preview(preview)
	return {"entry": entry,"grab_offset":grab_offset}
func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	if on_reserve_drop.is_valid(): return typeof(data) == TYPE_DICTIONARY and data.has("entry")
	var cell = get_parent()
	return cell.has_method("_can_drop_data") and cell._can_drop_data(at_position,data)
func _drop_data(at_position: Vector2, data: Variant) -> void:
	if on_reserve_drop.is_valid():
		on_reserve_drop.call(data.entry)
		return
	get_parent()._drop_data(at_position,data)
