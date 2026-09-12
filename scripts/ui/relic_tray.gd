extends Panel
# 控えの背景・空き枠へのドロップで装備解除。ラベルはmouse_filter=IGNORE、
# 所持品チップはon_reserve_dropで同じ解除処理へ転送する。
var on_drop: Callable
func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return typeof(data) == TYPE_DICTIONARY and data.has("entry")
func _drop_data(_at_position: Vector2, data: Variant) -> void:
	on_drop.call(data.entry)
