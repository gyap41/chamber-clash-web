extends Node2D
signal motion_started(kind: String, remaining_seconds: float)
# Animated seal; input and progression belong to the exploration controller.
var door_id := ""
var direction := Vector2.RIGHT
var opening_width := 112.0
var available := false
var locked := false
var caption: Label
# 2026-10-06: animation is stepped by exploration so inventory/focus pauses freeze it.
# 2026-10-07: user-adopted v3 gate and shared side-cutaway material.
static var gate_textures: Dictionary = {
	"north":preload("res://assets/stages/ashen-foundry-v2/dungeon-gate/north.tres"),
	"south":preload("res://assets/stages/ashen-foundry-v2/dungeon-gate/south.tres"),
	"west":preload("res://assets/stages/ashen-foundry-v2/dungeon-gate/north.tres"),
	"east":preload("res://assets/stages/ashen-foundry-v2/dungeon-gate/north.tres")}
static var gate_style: String = "integrated"
const Structure = preload("res://scripts/world/portcullis_structure.gd")
var gate_theme: Resource
var gate_origin := Vector2.ZERO
var closure: float = 0.0
var impact: float = 0.0
var motion_direction: int = 0
const CLOSE_SECONDS: float = .35
const OPEN_SECONDS: float = .65

func step(dt: float) -> void:
	var before: float = closure
	var previous_impact: float = impact
	var target: float = 1.0 if locked else 0.0
	var duration: float = CLOSE_SECONDS if locked else OPEN_SECONDS
	closure = move_toward(closure,target,maxf(dt,0.0)/duration)
	if before != closure:
		var movement: int = 1 if locked else -1
		if movement != motion_direction:
			motion_started.emit("gate_close" if locked else "gate_open",absf(target-before)*duration)
		motion_direction = movement
	if closure == target: motion_direction = 0
	impact = maxf(0.0,impact-dt)
	if locked and before < 1.0 and closure == 1.0: impact = .16
	if before != closure or previous_impact > 0.0: queue_redraw()

func passage_ready() -> bool:
	return not locked and closure <= 0.0
# Door pieces of the ashen foundry v2 set (docs/art/production/ashen-foundry-v2 stage 4): a stone sill across the
# opening and, while sealed, an iron beam over it. Both are flat floor pieces, so rotating them is fine.
const THRESHOLD = preload("res://assets/stages/ashen-foundry-v2/props/threshold.png")
const BARRIER = preload("res://assets/stages/ashen-foundry-v2/props/barrier.png")
const SILL_DEPTH := 20.0
const BARRIER_DEPTH := 14.0
func configure(entry: Dictionary, destination: String, _theme = null) -> void:
	gate_theme = _theme
	door_id = entry.id
	position = entry.position
	direction = entry.direction
	opening_width = float(entry.get("width",112.0))
	if gate_style in ["recessed","integrated"] and gate_textures.has(door_id):
		# Sort at the near foot, not at the old interaction point inside the wall.
		var near_foot: float = opening_width*.5 if direction.x != 0 else 0.0
		gate_origin = Vector2(0,-near_foot)
		position += Structure.mount(direction)+Vector2(0,near_foot)
		var shadow := Polygon2D.new()
		shadow.name = "GateContactShadow"
		shadow.z_index = -15
		shadow.color = Color(0,0,0,.22)
		var footprint: Rect2 = Rect2(-14,-opening_width*.5,34,opening_width+16) if direction.x != 0 else Rect2(-opening_width*.5-12,-2,opening_width+24,20)
		shadow.polygon = PackedVector2Array([footprint.position,Vector2(footprint.end.x,footprint.position.y),footprint.end,Vector2(footprint.position.x,footprint.end.y)])
		shadow.position = gate_origin
		add_child(shadow)
		if gate_style == "integrated":
			var passage := Structure.Passage.new()
			passage.name = "GatePassage"
			passage.z_index = -11
			passage.position = gate_origin
			passage.direction = direction
			passage.width = opening_width
			passage.theme = gate_theme
			passage.paint = Structure.draw_passage
			add_child(passage)
	caption = Label.new()
	caption.text = "F · "+destination
	caption.visible = false
	var inward := -direction
	caption.position = inward*(opening_width*.5+34)-Vector2(90,13)
	if direction.x != 0: caption.position += Vector2(-direction.x*50,opening_width*.25+11)
	caption.add_theme_font_size_override("font_size",14)
	caption.size = Vector2(180,26)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption.add_theme_color_override("font_color",Color("f3e7c6"))
	caption.add_theme_color_override("font_shadow_color",Color.BLACK)
	caption.add_theme_constant_override("shadow_offset_x",2)
	caption.add_theme_constant_override("shadow_offset_y",2)
	add_child(caption)
func set_available(value: bool) -> void:
	if available == value: return
	available = value
	caption.visible = false
	queue_redraw()
func set_locked(value: bool) -> void:
	if locked == value: return
	locked = value
	queue_redraw()
func _draw() -> void:
	# The field walls already form the stone returns. Do not cover them with
	# unrelated jamb sprites, or stretch wall coping across the walkable floor.
	# A flush, translucent sill preserves the continuous floor texture beneath it.
	# Long axis along the opening (the tangent of the exit direction).
	draw_set_transform(Vector2.ZERO,Vector2(-direction.y,direction.x).angle())
	# A side door's sill lies lengthwise across the view and reads as a pole; only north/south doors show one.
	if direction.x == 0 and not (gate_style in ["recessed","integrated"] and gate_textures.has(door_id)):
		draw_texture_rect(THRESHOLD,Rect2(-opening_width*.5,-SILL_DEPTH*.5,opening_width,SILL_DEPTH),false)
	if closure > 0.0 and not gate_textures.has(door_id):
		var length := opening_width-6
		# Existing adopted beam also retracts, while new gate artwork is under review.
		var visible_length: float = length*closure
		draw_texture_rect_region(BARRIER,Rect2(-length*.5,-BARRIER_DEPTH*.5,visible_length,BARRIER_DEPTH),Rect2(0,0,BARRIER.get_width()*closure,BARRIER.get_height()))
	draw_set_transform(Vector2.ZERO)
	if gate_textures.has(door_id): _draw_gate()
	if available and passage_ready():
		var tangent := Vector2(-direction.y,direction.x)
		draw_circle(-direction*13+tangent*(opening_width*.5-10),2,Color("d5b575"))

func _draw_gate() -> void:
	var texture: Texture2D = gate_textures[door_id]
	if gate_style == "integrated":
		Structure.draw_integrated(self,direction,opening_width,closure,impact,texture,gate_theme,gate_origin)
		return
	if gate_style == "recessed":
		Structure.draw(self,direction,opening_width,closure,impact,texture,gate_theme,gate_origin)
		return
	var side: bool = direction.x != 0
	var size: Vector2 = Vector2(28,opening_width+40) if side else Vector2(opening_width,56)
	var foot: Vector2 = Vector2(0,opening_width*.5) if side else Vector2.ZERO
	var rise: float = 1.0-closure*closure
	var bounce: float = sin(impact/.16*PI)*3.0
	var rect := Rect2(foot-Vector2(size.x*.5,size.y)-Vector2(0,rise*size.y+bounce),size)
	# Clip the panel as it retracts into the fixed winding housing.
	var shown: float = 1.0-rise
	var source := Rect2(0,texture.get_height()*(1.0-shown),texture.get_width(),texture.get_height()*shown)
	var visible_rect := Rect2(rect.position+Vector2(0,size.y*(1.0-shown)),Vector2(size.x,size.y*shown))
	if shown > 0.001: draw_texture_rect_region(texture,visible_rect,source)
	var housing := Rect2(foot-Vector2(size.x*.5+3,size.y+5),Vector2(size.x+6,8))
	draw_rect(housing,Color("292724"))
	draw_rect(housing.grow(-2),Color("44474a"))
