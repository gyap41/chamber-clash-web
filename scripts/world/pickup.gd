extends Node2D
const Weapons = preload("res://scripts/catalog/weapon_catalog.gd")
const Relics = preload("res://scripts/catalog/relic_catalog.gd")
@export var display_size := Vector2(44,33)
var kind := "weapon"
var gun := 0
var age := 0.0
var used := false
func configure(item_kind: String, id: int) -> void:
	kind = item_kind
	gun = id
	$Weapon.visible = kind == "weapon"
	$Ammo.visible = kind != "weapon"
	$Ammo.text = str(Relics.definition(id).glyph) if kind == "relic" else "AMMO"
	if kind == "relic": $Frame.default_color = Color(Relics.definition(id).color)
	if kind == "weapon":
		$Weapon.texture = Weapons.art(id)
		$Weapon.scale = display_size / $Weapon.texture.get_size()
		$Frame.default_color = Color("ffd071") if Weapons.definition(id).rarity == "S" else Color("a7dcf4")
func refresh(players: Array, ready_delay: float = .6) -> void:
	var text := "弾薬箱" if kind == "ammo" else str(Relics.definition(gun).name if kind == "relic" else Weapons.definition(gun).name)
	var hints: Array[String] = []
	for i in range(players.size()):
		var p = players[i]
		if position.distance_to(p.state.pos) < 82:
			if kind == "weapon" and not p.owns(gun) and p.inventory.size() >= 4:
				hints.append("P%d %s：装備中と交換" % [i+1,"G" if i == 0 else "H"])
			elif kind == "relic":
				var reason: String = p.field_relic_reason(gun)
				hints.append("P%d %s" % [i+1,("G：仮装備" if i == 0 else "H：仮装備") if reason == "" else reason])
			else: hints.append("近づいて取得")
	$Label.text = text
	$Hint.text = " / ".join(hints)
	$Label.visible = not hints.is_empty() or (kind == "weapon" and Weapons.definition(gun).rarity == "S")
	modulate.a = .55 if age < ready_delay else 1.0
