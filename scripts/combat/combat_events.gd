extends RefCounted
# Optional presentation subscriber. Combat never reads presentation results.
signal emitted(kind: String, args: Array)
func burst(pos: Vector2, color: Color, count: int) -> void: emitted.emit("burst",[pos,color,count])
func ring(pos: Vector2, color: Color, expansion: float) -> void: emitted.emit("ring",[pos,color,expansion])
func shake(strength: float) -> void: emitted.emit("shake",[strength])
func weapon_effect(row: int, pos: Vector2, angle: float = 0.0) -> void: emitted.emit("weapon_effect",[row,pos,angle])
func dodge_trail(pos: Vector2, color: Color) -> void: emitted.emit("dodge_trail",[pos,color])
func play_sound(kind: String, id: int = 0) -> void: emitted.emit("sound",[kind,id])
func pulse(pos: Vector2, slot: int) -> void: emitted.emit("pulse",[pos,slot])
