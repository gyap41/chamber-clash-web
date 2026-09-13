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

static var body_materials: Dictionary = {}
static func body_material(id: int, bounds: Vector2) -> ShaderMaterial:
	var body: Dictionary = profile(id).get("body",{})
	if not body.get("readable",false) and not body.get("rainbow",false): return null
	var key := "%d:%s" % [id,bounds]
	if not body_materials.has(key):
		var tex := texture(str(body.get("texture","")))
		var size := tex.get_size()*minf(bounds.x/tex.get_width(),bounds.y/tex.get_height())
		var mat := ShaderMaterial.new();mat.shader = preload("res://assets/shaders/equipment_readability.gdshader")
		mat.set_shader_parameter("outline",.6)
		mat.set_shader_parameter("outline_step",Vector2.ONE/size)
		mat.set_shader_parameter("rainbow",1.0 if body.get("rainbow",false) else 0.0)
		var colors := PackedColorArray()
		for color in profile(id).get("palette",["#ffffff","#ffffff","#ffffff","#ffffff","#ffffff","#ffffff","#ffffff"]):colors.append(Color(color))
		mat.set_shader_parameter("rainbow_palette",colors)
		body_materials[key]=mat
	return body_materials[key]
