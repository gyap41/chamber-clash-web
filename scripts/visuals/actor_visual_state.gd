extends RefCounted
## Value snapshot supplied by an actor. No actor, inventory or AI references.
## Timers are observations of combat authority, never modified by animation playback.
var character_id := -1
var alive := true
var moving := false
var move_speed := 205.0
var angle := 0.0
var direction := Vector2.RIGHT
var dodge_remaining := 0.0
var dodge_duration := .26
var dodge_action_locked := false
var reload_remaining := 0.0
var melee_active := false
var invulnerable := false
var armed := false
var shield_visible := false
var idle_offset := 0.0
var relic_colors: Array[Color] = []

func body_target() -> StringName:
	if not alive: return &"dead"
	if dodge_remaining > 0: return &"roll"
	return &"move" if moving else &"idle"

func weapon_target(firing: bool) -> StringName:
	if not alive: return &"disabled"
	if melee_active: return &"melee"
	if not armed: return &"disabled"
	if reload_remaining > 0: return &"reload"
	return &"fire" if firing else &"ready"

func dodge_progress() -> float:
	return clampf(1.0-dodge_remaining/maxf(dodge_duration,.001),0,1)

func weapon_visible() -> bool:
	return alive and armed and (character_id < 0 or not dodge_action_locked)
