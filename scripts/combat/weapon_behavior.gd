extends RefCounted
# Optional gameplay extension, separate from visual profiles and their RNG.
# Instances are short-lived. Keep persistent state on the supplied actor/projectile.
func on_event(_kind: StringName, _context: Dictionary) -> void:
	pass
