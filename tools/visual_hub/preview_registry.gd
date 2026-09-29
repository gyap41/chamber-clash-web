extends RefCounted
# New rendering methods register here; single and compare panels use this same lifecycle.
const Adapter = preload("res://tools/visual_hub/preview_adapter.gd")
var factories: Dictionary = {"enemy":func(): return preload("res://tools/visual_hub/enemy_preview.gd").new(),"actor":func(): return Adapter.new(),"stage":func(): return Adapter.new(),"image":func(): return Adapter.new()}
func register(method: String, factory: Callable) -> void: factories[method] = factory
func create_preview(parent: Node, record: Dictionary, conditions: Dictionary):
	var instance = factories.get(record.method,factories.image).call()
	parent.add_child(instance)
	instance.initialize(record,conditions)
	return instance
