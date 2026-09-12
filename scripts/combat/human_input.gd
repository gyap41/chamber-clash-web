extends RefCounted
const Command = preload("res://scripts/combat/combat_command.gd")
static func sample(player, shooting: bool) -> Dictionary:
	var command := Command.idle((player.get_global_mouse_position()-player.state.pos).angle())
	command.dx = float(Input.is_physical_key_pressed(KEY_D))-float(Input.is_physical_key_pressed(KEY_A))
	command.dy = float(Input.is_physical_key_pressed(KEY_S))-float(Input.is_physical_key_pressed(KEY_W))
	command.shoot = shooting
	return command
static func key(player, code: int) -> Dictionary:
	var command := Command.idle(player.state.angle)
	if code == KEY_E and not player.inventory.is_empty(): command.switch = (int(player.state.gun)+1)%player.inventory.size()
	if code >= KEY_1 and code <= KEY_8: command.switch = code-KEY_1
	command.reload = code == KEY_R
	command.dodge = code == KEY_SPACE
	command.pulse = code == KEY_Q
	command.interact = code == KEY_F
	return command
