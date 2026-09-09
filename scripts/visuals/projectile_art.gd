extends Sprite2D
# Tight source rectangles and anchors from legacy-web/dist/render.js.
const SHEET = preload("res://assets/effects/projectile-sprites.png")
const AtlasRegions = preload("res://scripts/visuals/atlas_regions.gd")
const FRAMES := [
	[Rect2(88,53,277,141),Rect2(492,70,330,124),Rect2(921,92,334,102),Rect2(1385,71,307,121)],
	[Rect2(101,273,254,142),Rect2(537,271,263,148),Rect2(980,277,262,145),Rect2(1412,276,253,142)],
	[Rect2(123,496,213,133),Rect2(539,492,224,138),Rect2(973,491,222,142),Rect2(1406,491,228,143)],
	[Rect2(84,693,285,132),Rect2(527,677,284,155),Rect2(970,692,286,133),Rect2(1420,693,276,132)]
]
const WIDTHS := [30.0,32.0,23.0,28.0]
const ANCHORS := [.76,.63,.75,.75]
var row := -1
var animation_frame := -1
static var atlases: Dictionary = {}

func configure(id: int, parcel: bool, shard: bool) -> void:
	row = -1 if shard else (0 if id == 16 else (1 if id == 17 and parcel else (2 if id == 18 else (3 if id == 19 else -1))))
	visible = row >= 0
	animation_frame = -1

func refresh(age: float, velocity: Vector2) -> void:
	if row < 0: return
	rotation = velocity.angle()
	var next := floori(age*12.0)%4
	if next == animation_frame: return
	animation_frame = next
	var key := row*4+next
	var rect: Rect2 = FRAMES[row][next]
	if not atlases.has(key):
		atlases[key] = AtlasRegions.region(SHEET, rect)
	texture = atlases[key]
	centered = false
	scale = Vector2.ONE*WIDTHS[row]/rect.size.x
	offset = Vector2(-rect.size.x*ANCHORS[row],-rect.size.y/2.0)
