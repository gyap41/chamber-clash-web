extends RefCounted
# P8 バックパックグリッド配置（配置基盤）：レリックの占有マスを「固定enum」ではなく相対
# オフセット座標のリストとして持たせる。基準マス（配置時に指定する1マス）からこのオフセット
# 群がすべて空いているかどうかだけを見れば当たり判定が成立するため、形状を後から増やしても
# match_state.gdのfits()/occupied_cells()側の作り直しは発生しない
# （claude/backpack-inventory-idea.md「追記：形状・回転の設計方針の再検討」参照）。
#
# 割り当ては今回のMVP向けの仮の値（playtestで調整する前提）。ほとんどのレリックは1×1のまま
# とし、象徴的な強力レリックだけを複数マス化した：
#   4（ライフアンプ）  ：縦2マスのドミノ
#   6（ヘビーコア）    ：横2マスのドミノ
#   2（プリズムレンズ）：L字トロミノ（3マス、非対称形状。ドキュメント推奨の「レア枠に最低
#                        1種類」に対応。プリズムレンズは将来の隣接シナジー案（対象武器の真下
#                        に置いた場合だけ反射ロックを解除する等）の候補でもあり、目立つ形状を
#                        割り当てる意味がある）
# 回転は未対応（ドキュメント方針どおり優先度を下げている）。
const SHAPES := {
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
