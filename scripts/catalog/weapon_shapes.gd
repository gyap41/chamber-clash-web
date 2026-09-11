extends RefCounted
# P8z 装備モデルの統合：武器もレリックと同じバックパックグリッドに置く。占有マスはレリックと
# 同じくオフセットリストで表す（scripts/catalog/relic_shapes.gd と同じ方式なので、match_state
# 側のfits()/occupied_cells()/auto_place()はそのまま使い回せる）。
#
# 決め方は「レア度で既定値、武器ごとに個別上書き」。強い武器ほどマスを食うので、レア度が上がる
# ほど自動的にグリッドを圧迫する（旧P8cの狙い）。既定値は下のRARITY_SHAPES、個性を出したい武器
# だけSHAPESで上書きする。すべてplaytest調整前提の仮値。
#
# 参考：段階1のグリッドは3×2＝6マス、段階5で4×4＝16マス。Sレア（4マス）は段階1の3マス幅に
# 収まらない形状もあるが、Sレアはラウンド開始45秒後の投下なので、実際に置けるようになるのは
# 段階2以降という想定。
const Weapons = preload("res://scripts/catalog/weapon_catalog.gd")
const RARITY_SHAPES := {
	"C": [Vector2i(0,0)],                                              # 1マス
	"B": [Vector2i(0,0),Vector2i(1,0)],                                # 横2マス
	"A": [Vector2i(0,0),Vector2i(1,0),Vector2i(0,1)],                  # L字3マス
	"S": [Vector2i(0,0),Vector2i(1,0),Vector2i(0,1),Vector2i(1,1)],    # 2×2の4マス
}
# 個別指定：レア度の既定値と同じマス数のまま形の向きだけ変えるもの（12/18）と、レア度より
# 長く取る代わりに置ける場所が限られるもの（6/9）。
const SHAPES := {
	6: [Vector2i(0,0),Vector2i(1,0),Vector2i(2,0)],                                  # アークレール(A)：横3マスのレール
	9: [Vector2i(0,0),Vector2i(1,0),Vector2i(2,0),Vector2i(3,0)],                    # コメットランチャー(S)：横4マス。幅4のグリッド（段階2以降）でしか置けない
	12: [Vector2i(0,0),Vector2i(0,1)],                                               # ロケットペンシル(B)：縦2マス
	18: [Vector2i(0,0),Vector2i(0,1)],                                               # スイッチスパナ(B)：縦2マス
}
const DEFAULT_SHAPE: Array = [Vector2i(0,0)]
static func shape(id: int) -> Array:
	if SHAPES.has(id): return SHAPES[id]
	if not Weapons.supported(id): return DEFAULT_SHAPE
	return RARITY_SHAPES.get(str(Weapons.definition(id).rarity), DEFAULT_SHAPE)
