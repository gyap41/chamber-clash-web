extends "res://scripts/game/combat_context.gd"
const ExplorationState = preload("res://scripts/game/exploration_state.gd")
const Rooms = preload("res://scripts/game/exploration_rooms.gd")
const Door = preload("res://scripts/world/exploration_door.gd")
var room_catalog: Dictionary = Rooms.ROOMS
var start_room := Rooms.START_ROOM
var exploration
var pause_reasons: Dictionary = {}
var doors: Array = []
var door_armed := true
var fire_requires_release := false
func _ready() -> void:
	# This prototype starts in a non-combat room. Remove the duel scene's extra
	# actors before registering participants/signals; never mutate a live roster.
	for actor in players.slice(1):
		actor.get_parent().remove_child(actor)
		actor.free()
	players = $Arena/Players.get_children()
	initialize_combat_context()
	hud.slot_requested.connect(func(index): equip_slot(0,index))
	hud.pause_requested.connect(toggle_pause)
	hud.retry_requested.connect(func():
		if phase == "result": start_exploration(Time.get_ticks_usec()))
	hud.title_requested.connect(return_to_title)
	hud.sound_requested.connect(func(): sound.set_enabled(not sound.enabled))
	combat.countdown_enabled = false
	combat.supplies_enabled = false
	var seed_value := Time.get_ticks_usec()
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--seed="): seed_value = int(argument.trim_prefix("--seed="))
	if "--stage-four-way" in OS.get_cmdline_user_args():
		room_catalog = preload("res://scripts/world/four_way_demo.gd").catalog()
		start_room = "crossroads"
	start_exploration(seed_value)
func start_exploration(seed_value: int) -> void:
	if not room_catalog.has(start_room):
		push_error("Start room is not in the room catalog")
		return
	var errors := Rooms.validation_errors(players[0].radius,room_catalog)
	if not errors.is_empty():
		push_error("; ".join(errors))
		return
	errors = arena.configure_field(room_data(start_room).field,1,players[0].radius)
	if not errors.is_empty():
		push_error("; ".join(errors))
		return
	clear_field_objects()
	clear_action_inputs()
	combat_visuals.clear()
	combat.reset_outcome()
	exploration = ExplorationState.new(seed_value)
	exploration.room_id = start_room
	exploration.visited_rooms = {start_room:true}
	telemetry = RunLog.new(seed_value)
	result = ""
	phase = "play"
	pause_reasons.clear()
	paused = false
	remaining = 0.0
	door_armed = true
	fire_requires_release = false
	fighters.clear()
	for i in range(players.size()):
		var player = players[i]
		player.set_character(0)
		player.reset(arena.spawn_position(i))
		player.telemetry = telemetry
		var inventory = exploration.inventory
		player.match_inventory = inventory
		player.match_player_index = 0
		player.apply_build(inventory.builds[0],inventory.capacity(0),true,inventory.usable_cells(0))
		fighters.append(player.state)
	fit_field_camera()
	rebuild_doors()
	get_node("/root/Music").play_context("play")
	refresh_hud()
func rebuild_doors() -> void:
	for node in doors:
		node.get_parent().remove_child(node)
		node.queue_free()
	doors.clear()
	for entry in room_data(exploration.room_id).doors:
		var node := Door.new()
		node.configure(entry,room_data(entry.target_room).name,arena.runtime_definition.theme)
		arena.add_child(node)
		arena.move_child(node,arena.get_node("Players").get_index())
		doors.append(node)
func nearby_door() -> Dictionary:
	for entry in room_data(exploration.room_id).doors:
		if players[0].state.pos.distance_to(entry.position) <= Rooms.INTERACT_RADIUS and not arena.line_blocked(players[0].state.pos,entry.position):
			return entry
	return {}
func try_enter_door() -> bool:
	if phase != "play" or paused or not result.is_empty() or players[0].state.hp <= 0 or not door_armed: return false
	if exploration.status != "active" or exploration.encounter_status == "active": return false
	var entry := nearby_door()
	if entry.is_empty(): return false
	var partner := door_data(entry.target_room,entry.target_door)
	if partner.is_empty(): return false
	var definition: FieldDefinition = room_data(entry.target_room).field.duplicate(true)
	definition.spawns = PackedVector2Array([partner.arrival])
	var was_firing: bool = mouse_fire_held or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	phase = "transition"
	var errors := switch_field(definition)
	phase = "play"
	if not errors.is_empty():
		push_error("; ".join(errors))
		return false
	exploration.room_id = entry.target_room
	exploration.visited_rooms[entry.target_room] = true
	door_armed = false
	fire_requires_release = was_firing
	rebuild_doors()
	refresh_hud()
	return true
func _input(event: InputEvent) -> void:
	super._input(event)
	if event is InputEventKey and event.keycode == KEY_F and not event.pressed: door_armed = true
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		fire_requires_release = false
func _unhandled_input(event: InputEvent) -> void:
	if fire_requires_release and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		get_viewport().set_input_as_handled()
		return
	super._unhandled_input(event)
func refresh_hud() -> void:
	var allowed: bool = phase == "play" and not paused and result.is_empty() and not players[0].is_cpu
	var view := preload("res://scripts/ui/combat_hud_view.gd").capture(players[0],allowed)
	hud.present(view,{"paused":paused,"result":result,"sound_enabled":sound.enabled,
		"room_name":room_data(exploration.room_id).name,"door_hint":door_hint(),
		"encounter_active":exploration.encounter_status == "active",
		"enemies_alive":players.slice(1).filter(func(player): return player.state.hp > 0).size()})
	var nearby := nearby_door()
	for node in doors: node.set_available(allowed and nearby.get("id","") == node.door_id)
func door_hint() -> String:
	var entry := nearby_door()
	if entry.is_empty(): return "扉に近づいて F で移動  ·  装備整理は今後追加"
	if exploration.encounter_status == "active": return "戦闘中は移動できません"
	return "F：%s へ移動" % room_data(entry.target_room).name
func toggle_pause() -> void:
	if phase != "play" or not result.is_empty(): return
	if pause_reasons.has("focus"): set_pause_reason("focus",false)
	else: set_pause_reason("menu",not pause_reasons.has("menu"))
func set_pause_reason(reason: String, enabled: bool) -> void:
	if enabled: pause_reasons[reason] = true
	else: pause_reasons.erase(reason)
	paused = not pause_reasons.is_empty()
	clear_action_inputs()
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_node_ready():
		set_pause_reason("focus",true)
func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	if event.keycode == KEY_ESCAPE:
		toggle_pause()
		return
	if phase == "play" and not paused and result.is_empty():
		if event.keycode == KEY_F:
			try_enter_door()
			get_viewport().set_input_as_handled()
			return
		apply_command(0,HumanInput.key(players[0],event.keycode))
func _physics_process(dt: float) -> void:
	if phase == "play" and not paused and result.is_empty():
		combat_visuals.step(dt)
		_step_pulse_effects(dt)
		combat.step(dt)
		exploration.settle(players[0].state.hp > 0,players.slice(1).any(func(p): return p.state.hp > 0))
		if exploration.status != "active":
			result = "探索終了" if exploration.status == "dead" else "試作戦闘クリア"
			phase = "result"
			clear_action_inputs()
			delayed_shots.clear()
			sound.stop_all()
			get_node("/root/Music").play_context("result")
	arena.get_node("DangerZone").refresh(0.0)
	arena.get_node("CombatCamera").offset = -combat_visuals.shake_offset
	refresh_hud()
func return_to_title() -> void:
	if is_queued_for_deletion(): return
	exploration.finish("abandoned")
	clear_action_inputs()
	set_physics_process(false)
	var title = load("res://scenes/ui/title.tscn").instantiate()
	get_tree().root.add_child(title)
	get_parent().remove_child(self)
	queue_free()

func room_data(id: String) -> Dictionary:
	return Rooms.room(id,room_catalog)
func door_data(room_id: String, id: String) -> Dictionary:
	return Rooms.door(room_id,id,room_catalog)
