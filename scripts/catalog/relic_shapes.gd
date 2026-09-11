extends RefCounted
# 基準マスからの固定オフセット。準備・戦闘の配置判定はbuild_grid.gdで共有する。
# 面積の判断理由はdocs/design/ITEM_FOOTPRINT_BALANCE.mdを参照。
# 回転・隣接効果は未実装。形状の数値はプレイ評価前の試作値。
const SHAPES := {
	20: [Vector2i(0,0),Vector2i(1,0)],
	21: [Vector2i(0,0),Vector2i(0,1)],
	24: [Vector2i(0,0),Vector2i(1,0)],
	27: [Vector2i(0,0),Vector2i(1,0)],
	28: [Vector2i(0,0),Vector2i(0,1)],
	32: [Vector2i(0,0),Vector2i(1,0)],
	0: [Vector2i(0,0),Vector2i(1,0)], # 移動+12%の面積効率を小型版と区別
	1: [Vector2i(0,0),Vector2i(1,0)], # 装填-35%は全携行武器に作用
	3: [Vector2i(0,0),Vector2i(1,0)], # 再使用可能な防御
	7: [Vector2i(0,0),Vector2i(1,0)], # 試作：初射強化は小型補正より大きい2マス
	4: [Vector2i(0,0),Vector2i(0,1)],
	6: [Vector2i(0,0),Vector2i(1,0)],
	2: [Vector2i(0,0),Vector2i(1,0),Vector2i(0,1)],
}
const DEFAULT_SHAPE: Array = [Vector2i(0,0)]
static func shape(id: int) -> Array:
	return SHAPES.get(id,DEFAULT_SHAPE)
