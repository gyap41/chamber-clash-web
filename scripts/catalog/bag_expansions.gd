extends RefCounted
# Equal-area, fixed-orientation prototypes. No item or reward slot is consumed.
const SHAPES := {
	"elbow": [Vector2i(0,0),Vector2i(1,0),Vector2i(0,1),Vector2i(1,1),Vector2i(0,2),Vector2i(0,3)],
	"rectangle": [Vector2i(0,0),Vector2i(1,0),Vector2i(2,0),Vector2i(0,1),Vector2i(1,1),Vector2i(2,1)],
}
const NAMES := {"elbow":"L字拡張","rectangle":"長方形拡張"}
