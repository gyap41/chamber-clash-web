extends RefCounted
# Presentation-only definitions. Never used to resolve damage or projectile rules.
static var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/weapon_visuals.json"))
static var textures: Dictionary = {}
const FALLBACK = preload("res://assets/first-workshop/bullet.png")

static func profile(id: int) -> Dictionary:
	var item: Dictionary = data.weapons.get(str(id),{})
	var family: String = str(item.get("family",data.default_family))
	var result: Dictionary = data.families.get(family,data.families[data.default_family]).duplicate(true)
	result.merge(item.duplicate(true),true)
	return result

static func texture(path: String) -> Texture2D:
	if path.is_empty() or not ResourceLoader.exists(path): return FALLBACK
	if not textures.has(path): textures[path] = load(path)
	return textures[path]

static func effect(id: int, event: String) -> Dictionary:
	var p := profile(id)
	var key: String = str(p.get(event,""))
	return data.effects.get(key,{})

static func bullet(id: int, variant: String = "") -> Dictionary:
	var p := profile(id)
	if data.variants.has(variant): return data.variants[variant]
	return {"texture":p.get("bullet",""),"size":p.get("bullet_size",[14,10])}

static func vec(values: Array) -> Vector2:
	return Vector2(float(values[0]),float(values[1]))

static func body_scales() -> Dictionary:
	var result := {}
	for id in data.weapons:
		result[int(id)] = float(data.weapons[id].get("body",{}).get("scale",1.0))
	return result

static func body_points() -> Dictionary:
	var result := {}
	for id in data.weapons:
		var body: Dictionary = data.weapons[id].get("body",{})
		if body.has("grip") and body.has("muzzle"):
			result[int(id)] = [vec(body.grip),vec(body.muzzle)]
	return result
