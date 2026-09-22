extends RefCounted
const Weapons = preload("res://scripts/catalog/weapon_catalog.gd")
const Relics = preload("res://scripts/catalog/relic_catalog.gd")
const Art = preload("res://scripts/ui/hud_assets.gd")
const INTERACT_RADIUS := 64.0

# Fixed P1 fixtures. Generated rewards and persistence belong to later phases.
static func entries(room_id: String, template_id: String = "") -> Array:
	if (room_id if template_id.is_empty() else template_id) != "workshop_trial": return []
	return [{"id":room_id+":weapon_1","kind":"weapon","item":1,"pos":Vector2(410,350),"label":str(Weapons.definition(1).name)},
		{"id":room_id+":relic_4","kind":"relic","item":4,"pos":Vector2(680,400),"label":str(Relics.definition(4).name)}]

static func nearby(entries: Array, collected: Dictionary, position: Vector2, arena) -> Dictionary:
	for loot in entries:
		if collected.has(loot.id): continue
		if position.distance_to(loot.pos) <= INTERACT_RADIUS and not arena.line_blocked(position,loot.pos): return loot
	return {}

static func collect(loot: Dictionary, progress) -> Dictionary:
	var acquired := false
	if not progress.collected_loot.has(loot.id):
		if loot.kind == "weapon": acquired = progress.inventory.store_field_weapon(0,loot.item)
		else: acquired = progress.inventory.store_field_relic(loot.item)
	if acquired: progress.collected_loot[loot.id] = true
	return {"acquired":acquired,"message":loot.label+"を取得しました  ·  Tabで配置して使用" if acquired else "取得できません：控えの空き・所持済み装備を確認  ·  Tab：バッグ"}

# The caller owns the node list; all state remains in ExplorationState.
static func rebuild(arena, entries: Array, collected: Dictionary, nodes: Array) -> void:
	for node in nodes:
		if is_instance_valid(node):
			node.get_parent().remove_child(node)
			node.queue_free()
	nodes.clear()
	for loot in entries:
		if collected.has(loot.id): continue
		var node := Node2D.new()
		node.position = loot.pos
		var sprite := Sprite2D.new()
		sprite.texture = Weapons.art(loot.item) if loot.kind == "weapon" else Art.texture("relic_%02d" % loot.item)
		sprite.scale = Vector2.ONE*36.0/maxf(sprite.texture.get_width(),sprite.texture.get_height())
		node.add_child(sprite)
		var label := Label.new()
		label.text = "F：取得"
		label.position = Vector2(-28,22)
		label.add_theme_font_size_override("font_size",12)
		node.add_child(label)
		arena.add_child(node)
		nodes.append(node)
