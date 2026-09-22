extends "res://scripts/game/combat_context.gd"
const ExplorationState = preload("res://scripts/game/exploration_state.gd")
const Rooms = preload("res://scripts/game/exploration_rooms.gd")
const Door = preload("res://scripts/world/exploration_door.gd")
const Floor = preload("res://scripts/game/exploration_floor.gd")
const FollowCamera = preload("res://scripts/visuals/exploration_camera.gd")
const Encounter = preload("res://scripts/game/exploration_encounter.gd")
var encounters_enabled := true
var random_floor := false
var floor_data: Dictionary = {}
var floor_map
var room_catalog: Dictionary = Rooms.ROOMS
var start_room := Rooms.START_ROOM
const Loot = preload("res://scripts/game/exploration_loot.gd")
const Loadout = preload("res://scripts/game/exploration_loadout.gd")
var bag
var loot_nodes: Array = []
var loot_message := ""
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
	hud.bag_requested.connect(open_bag)
	hud.map_requested.connect(open_map)
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
	if "--random-floor" in OS.get_cmdline_user_args(): random_floor = true
	if "--stage-four-way" in OS.get_cmdline_user_args():
		random_floor = false
		room_catalog = preload("res://scripts/world/four_way_demo.gd").catalog()
		start_room = "crossroads"
	start_exploration(seed_value)
func start_exploration(seed_value: int) -> void:
	if floor_map != null: close_map()
	if bag != null: close_bag()
	if random_floor:
		var generated := Floor.generate(seed_value)
		var generation_errors: PackedStringArray = generated.errors
		if generation_errors.is_empty(): generation_errors = Floor.validation_errors(generated)
		if generation_errors.is_empty():
			for room in generated.catalog.values():
				if not preload("res://scripts/world/room_reachability.gd").reachable(room): generation_errors.append("Unreachable room: "+room.display_name)
		if not generation_errors.is_empty():
			push_error("Floor generation rejected: "+str(generation_errors))
			set_physics_process(false)
			set_pause_reason("generation_error",true)
			var failure := AcceptDialog.new()
			failure.title = "探索を開始できません"
			failure.dialog_text = "階層の接続を確認できませんでした。タイトルへ戻ります。"
			failure.confirmed.connect(return_to_title)
			failure.canceled.connect(return_to_title)
			add_child(failure)
			failure.popup_centered()
			return
		floor_data = generated
		room_catalog = generated.catalog
		start_room = generated.start
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
	Encounter.retire(self)
	clear_action_inputs()
	combat_visuals.clear()
	combat.reset_outcome()
	exploration = ExplorationState.new(seed_value)
	exploration.visited_rooms.clear()
	exploration.enter_room(start_room,room_data(start_room).field.field_id)
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
	Loadout.capture(players[0],exploration.weapon_bank)
	loot_message = ""
	fit_field_camera()
	Encounter.begin(self)
	rebuild_doors()
	get_node("/root/Music").play_context("play")
	refresh_hud()
func rebuild_doors() -> void:
	rebuild_loot()
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
	loot_message = ""
	exploration.enter_room(entry.target_room,room_data(entry.target_room).field.field_id)
	Encounter.begin(self)
	door_armed = false
	fire_requires_release = was_firing
	rebuild_doors()
	refresh_hud()
	return true
func _input(event: InputEvent) -> void:
	if floor_map != null:
		if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_M,KEY_ESCAPE]:
			close_map()
			get_viewport().set_input_as_handled()
		return
	if bag != null:
		if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_TAB,KEY_ESCAPE]:
			close_bag()
			get_viewport().set_input_as_handled()
		return
	super._input(event)
	if event is InputEventKey and event.keycode == KEY_F and not event.pressed: door_armed = true
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		fire_requires_release = false
func _unhandled_input(event: InputEvent) -> void:
	if bag != null: return
	if fire_requires_release and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		get_viewport().set_input_as_handled()
		return
	super._unhandled_input(event)
func refresh_hud() -> void:
	var allowed: bool = phase == "play" and not paused and result.is_empty() and not players[0].is_cpu
	var view := preload("res://scripts/ui/combat_hud_view.gd").capture(players[0],allowed)
	hud.present(view,{"paused":paused,"result":result,"sound_enabled":sound.enabled,
		"map_available":not floor_data.is_empty(),"map_open":floor_map != null,
		"room_name":room_data(exploration.room_id).name,"door_hint":door_hint(),
		"encounter_active":exploration.encounter_status == "active",
		"encounter_cleared":exploration.encounter_status == "cleared",
		"bag_open":bag != null,"enemies_alive":players.slice(1).filter(func(player): return player.state.hp > 0).size()})
	var nearby := nearby_door()
	for node in doors:
		node.set_locked(exploration.encounter_status == "active")
		node.set_available(allowed and exploration.encounter_status != "active" and nearby.get("id","") == node.door_id)
func door_hint() -> String:
	if exploration.encounter_status == "active": return "敵を全滅させると出口が開きます  ·  Tab：バッグ"
	var loot := nearby_loot()
	if not loot.is_empty():
		if not loot_message.is_empty() and loot_message.begins_with("取得できません"): return loot_message
		return "F："+loot.label+"を控えへ取得  ·  Tab：バッグ"
	if not loot_message.is_empty(): return loot_message
	var entry := nearby_door()
	if entry.is_empty(): return "扉に近づいて F で移動  ·  Tab：バッグ"
	return "F：%s へ移動" % room_data(entry.target_room).name
func toggle_pause() -> void:
	if floor_map != null: close_map(); return
	if bag != null: close_bag(); return
	if phase != "play" or not result.is_empty(): return
	if pause_reasons.has("focus"): set_pause_reason("focus",false)
	else: set_pause_reason("menu",not pause_reasons.has("menu"))
func set_pause_reason(reason: String, enabled: bool) -> void:
	if enabled: pause_reasons[reason] = true
	else: pause_reasons.erase(reason)
	paused = not pause_reasons.is_empty()
	clear_action_inputs()
func _notification(what: int) -> void:
	if not is_node_ready(): return
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		set_pause_reason("focus",true)
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		# Resume only the focus pause; inventory and manual pauses remain active.
		set_pause_reason("focus",false)
func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	if event.keycode == KEY_M:
		open_map()
		get_viewport().set_input_as_handled()
		return
	if event.keycode == KEY_TAB:
		open_bag()
		get_viewport().set_input_as_handled()
		return
	if event.keycode == KEY_ESCAPE:
		toggle_pause()
		return
	if phase == "play" and not paused and result.is_empty():
		if event.keycode == KEY_F:
			if not try_collect_loot(): try_enter_door()
			get_viewport().set_input_as_handled()
			return
		apply_command(0,HumanInput.key(players[0],event.keycode))
func _physics_process(dt: float) -> void:
	if phase == "play" and not paused and result.is_empty():
		combat_visuals.step(dt)
		_step_pulse_effects(dt)
		var previous_weapon: int = players[0].weapon().id if players[0].has_weapon() else -1
		Loadout.capture(players[0],exploration.weapon_bank)
		combat.step(dt)
		var active_weapon: int = players[0].weapon().id if players[0].has_weapon() else -1
		if active_weapon != previous_weapon: Loadout.restore_active(players[0],exploration.weapon_bank)
		var was_active: bool = exploration.encounter_status == "active"
		exploration.settle(players[0].state.hp > 0,players.slice(1).any(func(p): return p.state.hp > 0))
		if was_active and exploration.encounter_status == "cleared":
			Encounter.retire(self)
			loot_message = "部屋クリア · 出口が開きました"
		if exploration.status != "active":
			result = "探索終了" if exploration.status == "dead" else "試作戦闘クリア"
			phase = "result"
			clear_action_inputs()
			delayed_shots.clear()
			sound.stop_all()
			get_node("/root/Music").play_context("result")
	if not paused:
		FollowCamera.follow(arena.get_node("CombatCamera"),arena.field_rect,players[0].state.pos)
	arena.get_node("DangerZone").refresh(0.0)
	arena.get_node("CombatCamera").offset = -combat_visuals.shake_offset
	refresh_hud()
func fit_field_camera() -> void:
	var target: Vector2 = players[0].state.get("pos",arena.spawn_position(0))
	if arena.runtime_definition.theme != null:
		$Exterior/Fill.color = arena.runtime_definition.theme.exterior_color
	FollowCamera.follow(arena.get_node("CombatCamera"),arena.field_rect,target,true)

func return_to_title() -> void:
	if is_queued_for_deletion(): return
	if exploration != null: exploration.finish("abandoned")
	clear_action_inputs()
	set_physics_process(false)
	var title = load("res://scenes/ui/title.tscn").instantiate()
	get_tree().root.add_child(title)
	get_parent().remove_child(self)
	queue_free()

func room_data(id: String) -> Dictionary:
	return Rooms.room(id,room_catalog)
func open_map() -> bool:
	if floor_data.is_empty() or paused or phase != "play" or exploration.status != "active": return false
	set_pause_reason("map",true)
	floor_map = preload("res://scripts/ui/exploration_map.gd").new()
	floor_map.floor_data = floor_data
	floor_map.current = exploration.room_id
	floor_map.visited = exploration.visited_rooms.duplicate()
	floor_map.room_states = exploration.room_states.duplicate(true)
	floor_map.close_requested.connect(close_map)
	add_child(floor_map)
	refresh_hud()
	return true
func close_map() -> void:
	if floor_map == null: return
	remove_child(floor_map)
	floor_map.queue_free()
	floor_map = null
	set_pause_reason("map",false)
	fire_requires_release = true
	refresh_hud()
func door_data(room_id: String, id: String) -> Dictionary:
	return Rooms.door(room_id,id,room_catalog)

func open_bag() -> bool:
	if bag != null or phase != "play" or paused or exploration.status != "active" or players[0].state.hp <= 0: return false
	Loadout.capture(players[0],exploration.weapon_bank)
	set_pause_reason("inventory",true)
	bag = preload("res://scripts/ui/exploration_bag.gd").new()
	bag.draft = Loadout.draft(exploration.inventory)
	bag.close_requested.connect(close_bag)
	bag.on_change = apply_bag_changes
	add_child(bag)
	refresh_hud()
	return true
func apply_bag_changes() -> bool:
	if bag == null: return false
	var valid: bool = phase == "play" and exploration.status == "active" and players[0].state.hp > 0
	var success: bool = valid and Loadout.apply(players[0],exploration.inventory,bag.draft.builds[0],exploration.weapon_bank)
	bag.draft = Loadout.draft(exploration.inventory)
	refresh_hud()
	return success
func close_bag() -> bool:
	if bag == null: return false
	bag.get_parent().remove_child(bag)
	bag.queue_free()
	bag = null
	set_pause_reason("inventory",false)
	fire_requires_release = true
	refresh_hud()
	return true
func apply_command(index: int, command: Dictionary) -> void:
	if bag != null or paused or exploration == null: return
	Loadout.capture(players[0],exploration.weapon_bank)
	var old: int = players[0].weapon().id if players[0].has_weapon() else -1
	super.apply_command(index,command)
	if old != (players[0].weapon().id if players[0].has_weapon() else -1):
		Loadout.restore_active(players[0],exploration.weapon_bank)
# Compatibility entry points; pickup policy and presentation live in ExplorationLoot.
func room_loot() -> Array:
	if not floor_data.is_empty() and floor_data.rooms[exploration.room_id].role == "start":
		return Loot.entries(exploration.room_id,"workshop_trial")
	return Loot.entries(exploration.room_id,room_data(exploration.room_id).field.field_id)
func nearby_loot() -> Dictionary:
	return Loot.nearby(room_loot(),exploration.collected_loot,players[0].state.pos,arena)
func try_collect_loot() -> bool:
	if paused or phase != "play" or players[0].state.hp <= 0: return false
	var loot := nearby_loot()
	if loot.is_empty(): return false
	var outcome := Loot.collect(loot,exploration)
	loot_message = outcome.message
	if outcome.acquired: rebuild_loot()
	return true
func rebuild_loot() -> void:
	Loot.rebuild(arena,room_loot(),exploration.collected_loot,loot_nodes)
