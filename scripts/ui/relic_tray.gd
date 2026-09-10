extends Panel
# P8 配置基盤：グリッド外の「ここへドラッグで外す」専用ドロップ領域。意図的に子コントロール
# を持たせない（子にRelicChip等を重ねると、Godotのドロップ判定がその子で止まってしまい
# パネル自体がドロップを受け取れなくなるため。控え一覧の表示は別の場所に並べる）。
var on_drop: Callable
func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return typeof(data) == TYPE_DICTIONARY and data.has("relic_id")
func _drop_data(_at_position: Vector2, data: Variant) -> void:
	on_drop.call(int(data.relic_id))
