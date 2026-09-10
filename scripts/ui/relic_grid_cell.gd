extends Panel
# P8 配置基盤：グリッドの1マス。ドロップされたレリックが、このマスを基準マスとして自分の
# 形状（scripts/catalog/relic_shapes.gd）ぶんすべて空いている場合のみ受け入れる
# （判定自体はmatch_state.fits()に委譲、当たり判定ロジックの重複を避ける）。
# 子にRelicChipを乗せる／乗せないのはpreparation.gd側の責務（このスクリプトは当たり判定と
# 委譲のみ）。
var game
var player_index := 0
var cell := Vector2i.ZERO
var on_drop: Callable
func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if typeof(data) != TYPE_DICTIONARY or not data.has("relic_id"): return false
	return game.match_state.fits(player_index,int(data.relic_id),cell,int(data.relic_id))
func _drop_data(_at_position: Vector2, data: Variant) -> void:
	on_drop.call(int(data.relic_id),cell)
