extends RefCounted
# One frame of intent. No Node references, device codes or participant ownership in payload.
static func idle(angle: float = 0.0) -> Dictionary:
	return {"dx":0.0,"dy":0.0,"angle":angle,"aim_jitter":0.0,"shoot":false,"fire_pressed":false,"switch":-1,"reload":false,"dodge":false,"melee":false,"pulse":false,"interact":false}
