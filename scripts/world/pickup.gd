extends Node2D
const Weapons = preload("res://scripts/catalog/weapon_catalog.gd")
const Relics = preload("res://scripts/catalog/relic_catalog.gd")
@export var display_size := Vector2(44,33)
var kind := "weapon"
var gun := 0
var age := 0.0
var used := false
# P7 宝箱演出：武器・レリックは「宝箱」化し、触れるだけでは入手できない。-1は未開封。
# supplies.gdのinteract()/step()がこの2つを書き換えて開封の進行を管理する（無敵化はしない）。
var opening_player := -1
var open_progress := 0.0
func configure(item_kind: String, id: int) -> void:
	kind = item_kind
	gun = id
	opening_player = -1
	open_progress = 0.0
	$Weapon.visible = kind == "weapon"
	$Ammo.visible = kind != "weapon"
	$Ammo.text = str(Relics.definition(id).glyph) if kind == "relic" else "AMMO"
	# P7 宝箱演出：武器・レリックは弾薬箱と見た目を分け、四角い$Frameの代わりに宝箱シルエット
	# （$ChestFrame、Polygon2D/Line2Dのみで構成した仮アート）をレア度／レリック色で表示する。
	# 弾薬箱は従来どおり$Frameの単純な四角枠のまま（色も既定値のまま変更しない）。
	$Frame.visible = kind == "ammo"
	$ChestFrame.visible = kind in ["weapon","relic"]
	if kind == "relic":
		var relic_color := Color(Relics.definition(id).color)
		$ChestFrame/Body.color = relic_color
		$ChestFrame/Lid.color = relic_color.darkened(.25)
	if kind == "weapon":
		$Weapon.texture = Weapons.art(id)
		$Weapon.scale = display_size / $Weapon.texture.get_size()
		var rarity_color := Weapons.rarity_color(id) # 色分けレア度：C/B/A/Sの4段階
		$ChestFrame/Body.color = rarity_color
		$ChestFrame/Lid.color = rarity_color.darkened(.25)
	# $ChestArt は将来の宝箱画像（レア度別）を差し込むためのプレースホルダー。本番素材が来たら
	# ここへtextureを設定し、$ChestFrameは非表示にする想定（今回はテクスチャなし・非表示のまま
	# で、configure()/refresh()からはまだ参照しない）。
func refresh(players: Array, ready_delay: float = .6, open_seconds: float = 0.0) -> void:
	var text := "弾薬箱" if kind == "ammo" else str(Relics.definition(gun).name if kind == "relic" else Weapons.definition(gun).name)
	if opening_player >= 0:
		open_seconds = players[opening_player].effective_chest_duration(open_seconds)
	var hints: Array[String] = []
	var is_chest: bool = kind in ["weapon","relic"]
	for i in range(players.size()):
		var p = players[i]
		if position.distance_to(p.state.pos) < 82:
			if kind == "ammo":
				hints.append("近づいて取得")
			elif opening_player == i:
				hints.append("開封中…%.1f/%.1f秒" % [minf(open_progress,open_seconds),open_seconds])
			elif opening_player != -1:
				hints.append("P%dが開封中" % (opening_player+1))
			elif kind == "weapon":
				var reason: String = p.field_weapon_reason(gun)
				hints.append("P%d %s" % [i+1,("F：控えへ（次の準備で配置）" if i == 0 else "H：控えへ（次の準備で配置）") if reason.is_empty() else reason])
			elif kind == "relic":
				var reason: String = p.field_relic_reason(gun)
				hints.append("P%d %s" % [i+1,("F：開封" if i == 0 else "H：開封") if reason == "" else reason])
	$Label.text = text
	$Hint.text = " / ".join(hints)
	$Label.visible = not hints.is_empty() or (kind == "weapon" and Weapons.definition(gun).rarity == "S")
	modulate.a = .55 if age < ready_delay else 1.0
	$OpenProgress.visible = is_chest and opening_player != -1 and open_seconds > 0.0
	if $OpenProgress.visible: $OpenProgress.value = clampf(open_progress/open_seconds,0.0,1.0)
