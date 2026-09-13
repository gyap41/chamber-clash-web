extends RefCounted
const Base = preload("res://scripts/combat/weapon_behavior.gd")
const Catalog = preload("res://scripts/catalog/game_catalog.gd")
static var scripts: Dictionary = {}
static func dispatch(id: int, kind: StringName, context: Dictionary) -> void:
	context = context.duplicate()
	var actor = context.get("actor")
	if not context.has("session") and actor != null and actor.combat_service != null:
		context.session = actor.combat_service.get_ref()
	var definition: Dictionary = Catalog.definition("guns",id)
	for path in definition.get("behaviors",[]):
		if not scripts.has(path):
			if not ResourceLoader.exists(str(path)):
				push_error("Missing weapon behavior: %s" % path)
				continue
			scripts[path] = load(str(path))
		var script = scripts[path]
		if not script is Script: continue
		var behavior = script.new()
		if behavior is Base: behavior.on_event(kind,context)
