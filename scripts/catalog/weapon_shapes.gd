extends RefCounted
# P8z 装備モデルの統合：武器もレリックと同じバックパックグリッドに置く。占有マスはレリックと
# 同じくオフセットリストで表す（scripts/catalog/relic_shapes.gd と同じ方式なので、match_state
# 側のfits()/occupied_cells()/auto_place()はそのまま使い回せる）。
#
# 決め方は「レア度で既定値、武器ごとに個別上書き」。強い武器ほどマスを食うので、レア度が上がる
# ほど自動的にグリッドを圧迫する（旧P8cの狙い）。既定値は下のRARITY_SHAPES、個性を出したい武器
# だけSHAPESで上書きする。すべてplaytest調整前提の仮値。
#
# 試作：最大6×6表示、初期8〜開放上限24マス。Sの既定形状は6マスへ調整し、
# コメット6、プラネタリウム9マス。理由は docs/design/ITEM_FOOTPRINT_BALANCE.md。
const Weapons = preload("res://scripts/catalog/weapon_catalog.gd")
const RARITY_SHAPES := {
	"C": [Vector2i(0,0),Vector2i(1,0)],                                # 継続使用武器は最低2マス
	"B": [Vector2i(0,0),Vector2i(1,0)],                                # 横2マス
	"A": [Vector2i(0,0),Vector2i(1,0),Vector2i(0,1)],                  # L字3マス
	"S": [Vector2i(0,0),Vector2i(1,0),Vector2i(2,0),Vector2i(0,1),Vector2i(1,1),Vector2i(2,1)],    # 試作：3×2の6マス
}
# 個別指定：レールの横長、ペンシル/スパナの縦長、コメット6マス、プラネタリウム9マス。
const SHAPES := {
	15: [Vector2i(0,0),Vector2i(1,0),Vector2i(2,0),Vector2i(0,1),Vector2i(1,1),Vector2i(2,1),Vector2i(0,2),Vector2i(1,2),Vector2i(2,2)], # 12方向の追尾・反射弾：3×3の9マス
	6: [Vector2i(0,0),Vector2i(1,0),Vector2i(2,0)],                                  # アークレール(A)：横3マスのレール
	9: [Vector2i(0,0),Vector2i(1,0),Vector2i(2,0),Vector2i(0,1),Vector2i(1,1),Vector2i(2,1)],                    # コメット：爆風と12破片を考慮し3×2の6マス
	12: [Vector2i(0,0),Vector2i(0,1)],                                               # ロケットペンシル(B)：縦2マス
	18: [Vector2i(0,0),Vector2i(0,1)],                                               # スイッチスパナ(B)：縦2マス
}
const DEFAULT_SHAPE: Array = [Vector2i(0,0),Vector2i(1,0)]
static func shape(id: int) -> Array:
	if SHAPES.has(id): return SHAPES[id]
	if not Weapons.supported(id): return DEFAULT_SHAPE
	return RARITY_SHAPES.get(str(Weapons.definition(id).rarity), DEFAULT_SHAPE)
