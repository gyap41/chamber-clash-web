extends RefCounted
const Relics = preload("res://scripts/catalog/relic_catalog.gd")
var rng := RandomNumberGenerator.new()
func _init(value: int = 1) -> void:
	rng.seed = value
func shuffled(pool: Array) -> Array:
	var result := pool.duplicate()
	for i in range(result.size()-1,0,-1):
		var j := rng.randi_range(0,i)
		var value = result[i]
		result[i] = result[j]
		result[j] = value
	return result
func candidates(base: Array, owned: Array, count: int = 3) -> Array:
	var result: Array = []
	for id in base + shuffled(Relics.SUPPORTED):
		if (id not in owned or Relics.stackable(id)) and id not in result: result.append(id)
		if result.size() >= count: break
	return result
