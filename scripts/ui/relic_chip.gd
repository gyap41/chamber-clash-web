extends Button
# P8 配置基盤：所持レリックをグリッド／控えへドラッグするための「つまみ」。クリックには何も
# 割り当てない（着脱・移動はドロップ側 [relic_grid_cell.gd / relic_tray.gd] が処理する）。
var relic_id := -1
func _get_drag_data(_at_position: Vector2) -> Variant:
	var preview := Button.new()
	preview.text = text
	preview.custom_minimum_size = custom_minimum_size
	preview.modulate.a = .7
	set_drag_preview(preview)
	return {"relic_id": relic_id}
