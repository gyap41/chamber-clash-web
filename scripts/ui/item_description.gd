extends RefCounted
# Shared, read-only descriptions for shop inspection and bag selection.
const Weapons = preload("res://scripts/catalog/weapon_catalog.gd")
const Relics = preload("res://scripts/catalog/relic_catalog.gd")
const Items = preload("res://scripts/game/item_identity.gd")
const Grid = preload("res://scripts/game/build_grid.gd")
static func describe(kind: String, id: int, inventory, preview_addition: bool = false, exploration_starter: bool = false) -> String:
	var data: Dictionary = Weapons.definition(id) if kind == "weapon" else Relics.definition(id)
	if kind == "weapon" and id == 20 and exploration_starter:
		data = data.duplicate()
		data.damage *= .55
		data.desc = "探索用の初期武器。予備弾は無限・威力55%。装填は必要です。"
	var token = Items.gun_token(id) if kind == "weapon" else Items.relic_token(id,0)
	var text := "%s\n%s\n\n" % [data.name,data.get("desc","")]
	if kind == "weapon":
		text += "レア度 %s ／ 基礎威力 %.2f\n%s\n" % [data.rarity,float(data.damage),Weapons.stats_text(data).replace("予備 %d" % int(data.stock),"予備 ∞") if kind == "weapon" and id == 20 and exploration_starter else Weapons.stats_text(data)]
	else:
		text += "レア度 %s\n" % Relics.rarity(id)
		var count: int = Items.relic_ids(inventory.builds[0].equipped).count(id)
		if Relics.stackable(id):
			text += "重複強化可能 ／ 装備中 %d個\n" % count
			text += ("追加装備時：%s → %s\n" % [Relics.stack_summary(id,count),Relics.stack_summary(id,count+1)]) if preview_addition else ("現在の合計：%s\n" % Relics.stack_summary(id,count))
		else: text += "同種は1個まで（重複効果なし）\n"
	if not str(data.get("details","")).is_empty():
		text += "\n補足：%s\n" % data.details
	text += "\n必要な面積：%dマス" % Grid.shape_of(token).size()
	return text
