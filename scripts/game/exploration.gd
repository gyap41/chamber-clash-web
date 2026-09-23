extends "res://scripts/game/combat_context.gd"
const ExplorationState = preload("res://scripts/game/exploration_state.gd")
const Rooms = preload("res://scripts/game/exploration_rooms.gd")
const Door = preload("res://scripts/world/exploration_door.gd")
const Floor = preload("res://scripts/game/exploration_floor.gd")
const FollowCamera = preload("res://scripts/visuals/exploration_camera.gd")
const Encounter = preload("res://scripts/game/exploration_encounter.gd")
const Reward = preload("res://scripts/game/exploration_reward.gd")
const BossFlow = preload("res://scripts/game/exploration_boss_flow.gd")
var boss_intro_seen := false
var chest_node
const ExplorationSupplies = preload("res://scripts/game/exploration_supplies.gd")
var supply_nodes: Array = []
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
	sound.stop_all()
	clear_enemy_deaths()
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
	else:
		var dressed_catalog := {}
		for id in room_catalog:
			var room = room_catalog[id].duplicate(true)
			preload("res://scripts/world/ashen_foundry_dressing.gd").apply(room,"start" if id == start_room else "normal",1)
			dressed_catalog[id] = room
		room_catalog = dressed_catalog
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
	sound.pause_boss_audio(false)
	remaining = 0.0
	door_armed = true
	fire_requires_release = false
	fighters.clear()
	for i in range(players.size()):
		var player = players[i]
		player.set_character(0)
		player.max_hp = 4.0
		player.rally_enabled = false
		player.reset(arena.spawn_position(i))
		player.telemetry = telemetry
		var inventory = exploration.inventory
		player.match_inventory = inventory
		player.match_player_index = 0
		player.exploration_starter = true
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
	Reward.ensure_treasure(self)
	rebuild_loot()
	rebuild_chest()
	rebuild_supplies()
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
	if BossFlow.blocks_exit(self): return false
	if BossFlow.is_room(self) and not BossFlow.blocks_exit(self):
		door_armed = false
		clear_action_inputs()
		exploration.finish("completed")
		return true
	var partner := door_data(entry.target_room,entry.target_door)
	if partner.is_empty(): return false
	var definition: FieldDefinition = room_data(entry.target_room).field.duplicate(true)
	definition.spawns = PackedVector2Array([partner.arrival])
	var was_firing: bool = mouse_fire_held or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	phase = "transition"
	clear_enemy_deaths()
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
	if boss_intro():
		if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ENTER:
			BossFlow.finish_intro(self)
			get_viewport().set_input_as_handled()
		return
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
	if bag != null or boss_intro(): return
	if fire_requires_release and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		get_viewport().set_input_as_handled()
		return
	super._unhandled_input(event)
func refresh_hud() -> void:
	var allowed: bool = phase == "play" and not paused and result.is_empty() and not players[0].is_cpu and not boss_intro()
	var view := preload("res://scripts/ui/combat_hud_view.gd").capture(players[0],allowed)
	hud.present(view,{"paused":paused,"result":result,"sound_enabled":sound.enabled,
		"boss":boss_hud(),"map_available":not floor_data.is_empty(),"map_open":floor_map != null,
		"room_role":floor_data.rooms[exploration.room_id].role if not floor_data.is_empty() else "",
		"reward_state":Reward.current(self).get("state",""),
		"room_name":room_data(exploration.room_id).name,"door_hint":door_hint(),
		"encounter_active":exploration.encounter_status == "active",
		"encounter_cleared":exploration.encounter_status == "cleared",
		"bag_open":bag != null,"enemies_alive":players.slice(1).filter(func(player): return player.state.hp > 0).size()})
	var nearby := nearby_door()
	for node in doors:
		node.set_locked(exploration.encounter_status == "active" or BossFlow.blocks_exit(self))
		node.set_available(allowed and exploration.encounter_status != "active" and not BossFlow.blocks_exit(self) and nearby.get("id","") == node.door_id)
func door_hint() -> String:
	if boss_intro(): return ""
	if BossFlow.is_room(self) and exploration.encounter_status == "cleared":
		var boss_reward := Reward.current(self)
		if boss_reward.get("state","") == "forming": return ""
		if not nearby_door().is_empty() and not BossFlow.blocks_exit(self): return "F：工房を踏破して帰還" if not nearby_door().is_empty() else loot_message
		if Reward.nearby(self) and loot_message.begins_with("取得できません"): return loot_message
		if Reward.nearby(self): return "F：鋳造機の遺産を開く" if boss_reward.state == "closed" else "F：アイテムを拾う · Tab：バッグ整理"
		return ""
	if exploration.encounter_status == "active": return "敵を全滅させると出口が開きます  ·  Tab：バッグ"
	if Reward.nearby(self):
		if Reward.current(self).state == "closed": return "F：宝箱を開く"
		if loot_message.begins_with("取得できません"): return loot_message
		return "F："+str(Reward.current(self).label)+"を控えへ取得  ·  Tab：バッグ"
	var supply := ExplorationSupplies.nearby(self)
	if not supply.is_empty():
		if "残しました" in loot_message: return loot_message+"  ·  F：再取得"
		return "F：HPを2回復" if supply.kind == "heal" else "F：装備中の武器へ弾薬補給"
	var loot := nearby_loot()
	if not loot.is_empty():
		if not loot_message.is_empty() and loot_message.begins_with("取得できません"): return loot_message
		return "F："+loot.label+"を控えへ取得  ·  Tab：バッグ"
	var entry := nearby_door()
	if entry.is_empty(): return loot_message if not loot_message.is_empty() else "扉に近づいて F で移動  ·  Tab：バッグ"
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
	sound.pause_boss_audio(paused)
	clear_action_inputs()
func _notification(what: int) -> void:
	if not is_node_ready(): return
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		set_pause_reason("focus",true)
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		# Resume only the focus pause; inventory and manual pauses remain active.
		set_pause_reason("focus",false)
func _unhandled_key_input(event: InputEvent) -> void:
	if boss_intro() and event is InputEventKey and event.keycode != KEY_ESCAPE: return
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
			if not try_chest() and not try_supply() and not try_collect_loot(): try_enter_door()
			get_viewport().set_input_as_handled()
			return
		apply_command(0,HumanInput.key(players[0],event.keycode))
func _physics_process(dt: float) -> void:
	if phase == "result" and not paused:
		for remains in get_tree().get_nodes_in_group("enemy_death_visuals"):
			if is_ancestor_of(remains): remains.step(dt)
	if phase == "play" and not paused and result.is_empty():
		for remains in get_tree().get_nodes_in_group("enemy_death_visuals"):
			if is_ancestor_of(remains): remains.step(dt)
		if is_instance_valid(chest_node): chest_node.step(dt)
		BossFlow.step_reward(self,dt)
		combat_visuals.step(dt)
		_step_pulse_effects(dt)
		var previous_weapon: int = players[0].weapon().id if players[0].has_weapon() else -1
		Loadout.capture(players[0],exploration.weapon_bank)
		if boss_intro():
			clear_action_inputs()
			BossFlow.step_intro(self,dt)
		else:
			combat.step(dt)
		var active_weapon: int = players[0].weapon().id if players[0].has_weapon() else -1
		if active_weapon != previous_weapon: Loadout.restore_active(players[0],exploration.weapon_bank)
		var was_active: bool = exploration.encounter_status == "active"
		exploration.settle(players[0].state.hp > 0,players.slice(1).any(func(p): return p.state.hp > 0))
		if was_active and exploration.encounter_status == "cleared":
			var defeated_at: Vector2 = players[1].state.pos if players.size() > 1 else players[0].state.pos
			Encounter.retire(self)
			loot_message = "部屋クリア · 出口が開きました"
			if not floor_data.is_empty() and floor_data.rooms[exploration.room_id].role == "boss":
				BossFlow.begin_reward(self,defeated_at)
			if exploration.status == "active" and not BossFlow.is_room(self) and Reward.ensure(self):
				rebuild_chest()
				chest_node.spawning = .4
				sound.play_sound("chest_spawn")
				loot_message = "部屋クリア · 宝箱が出現しました"
			if ExplorationSupplies.ensure(self): rebuild_supplies()
		if exploration.status != "active":
			if players.size() > 1: Encounter.retire(self)
			result = "探索終了" if exploration.status == "dead" else "工房踏破！ 独楽の鋳造機を撃破"
			phase = "result"
			clear_action_inputs()
			delayed_shots.clear()
			sound.stop_all(exploration.status == "completed")
			if exploration.status == "completed": sound.play_sound("win")
			get_node("/root/Music").play_context("result")
	if not paused:
		var boss_alive: bool = phase == "play" and players.size() > 1 and players[1].get("spec") != null and players[1].spec.id == "furnace_warden" and players[1].state.hp > 0
		if boss_alive:
			sound.update_boss_engine(true,players[1].state.pos.distance_to(players[0].state.pos),1.0 if players[1].attack_phase == "dash" else .5 if players[1].second_phase else 0.0)
		else:
			sound.update_boss_engine(false)
		var camera_target: Vector2 = players[0].state.pos
		if boss_intro():
			var progress: float = 1.0-players[1].attack_time/players[1].startup_total
			camera_target = camera_target.lerp(players[1].state.pos,sin(progress*PI)*.7)
		FollowCamera.follow(arena.get_node("CombatCamera"),arena.field_rect,camera_target)
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
	if floor_data.is_empty() or boss_intro() or paused or phase != "play" or exploration.status != "active": return false
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
	if bag != null or boss_intro() or phase != "play" or paused or exploration.status != "active" or players[0].state.hp <= 0: return false
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
	if bag != null or paused or exploration == null or boss_intro(): return
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

func rebuild_chest() -> void:
	if is_instance_valid(chest_node):
		chest_node.get_parent().remove_child(chest_node)
		chest_node.queue_free()
	chest_node = null
	var reward := Reward.current(self)
	if reward.is_empty(): return
	chest_node = preload("res://scripts/world/exploration_chest.gd").new()
	if reward.get("source","") == "boss": chest_node.landed.connect(func(): sound.play_sound("landing"))
	if not reward.has("drop_offset"):
		reward.drop_offset = Reward.scatter_offsets(arena,reward.pos,hash(str(exploration.seed_value)+str(reward.id)+":scatter"),1)[0]
	chest_node.reward = reward
	chest_node.position = reward.pos
	arena.get_node("Players").add_child(chest_node)

func clear_enemy_deaths() -> void:
	if not is_inside_tree(): return
	for remains in get_tree().get_nodes_in_group("enemy_death_visuals"):
		if is_ancestor_of(remains):
			remains.get_parent().remove_child(remains)
			remains.queue_free()

func rebuild_supplies() -> void:
	for node in supply_nodes:
		if is_instance_valid(node):
			node.get_parent().remove_child(node)
			node.queue_free()
	supply_nodes.clear()
	for entry in ExplorationSupplies.entries(self):
		if entry.taken: continue
		var node := preload("res://scripts/world/exploration_supply.gd").new()
		node.kind = entry.kind
		node.position = entry.pos
		arena.get_node("Players").add_child(node)
		supply_nodes.append(node)

func try_supply() -> bool:
	if paused or phase != "play" or exploration.status != "active" or players[0].state.hp <= 0 or exploration.encounter_status == "active": return false
	var entry := ExplorationSupplies.nearby(self)
	if entry.is_empty(): return false
	if not door_armed: return true
	door_armed = false
	var outcome := ExplorationSupplies.collect(self,entry)
	loot_message = outcome.message
	if outcome.acquired:
		sound.play_sound("heal" if entry.kind == "heal" else "ammo_pickup")
		rebuild_supplies()
	refresh_hud()
	return true

func try_chest() -> bool:
	if paused or phase != "play" or exploration.status != "active" or players[0].state.hp <= 0 or exploration.encounter_status == "active": return false
	if not Reward.nearby(self): return false
	# Use the same release latch as doors so opening cannot also acquire or leave.
	if not door_armed: return true
	door_armed = false
	var reward := Reward.current(self)
	if chest_node.spawning > 0: return true
	if reward.state == "closed":
		reward.state = "open"
		chest_node.opening = chest_node.OPEN_DURATION
		sound.play_sound("chest_open")
		loot_message = "宝箱を開きました · Fで中身を取得"
	elif chest_node.opening <= 0:
		if reward.get("source","") == "boss":
			BossFlow.claim(self)
			return true
		var outcome := Loot.collect(reward,exploration)
		loot_message = outcome.message
		if outcome.acquired:
			reward.state = "empty"
			sound.play_sound("pickup")
	chest_node.queue_redraw()
	refresh_hud()
	return true

func boss_intro() -> bool:
	return exploration != null and players.size() == 2 and players[1].get("spec") != null and players[1].spec.id == "furnace_warden" and players[1].attack_phase == "grace"

func boss_hud() -> Dictionary:
	if players.size() != 2 or players[1].get("spec") == null or players[1].spec.id != "furnace_warden": return {}
	return {"hp":players[1].state.hp,"max_hp":players[1].state.max_hp,"intro":boss_intro(),"second":players[1].second_phase}
