extends "res://scripts/game/combat_context.gd"
const ExplorationState = preload("res://scripts/game/exploration_state.gd")
var exploration
var pause_reasons: Dictionary = {}
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
	start_exploration(seed_value)
func start_exploration(seed_value: int) -> void:
	clear_field_objects()
	clear_action_inputs()
	combat_visuals.clear()
	combat.reset_outcome()
	exploration = ExplorationState.new(seed_value)
	telemetry = RunLog.new(seed_value)
	result = ""
	phase = "play"
	pause_reasons.clear()
	paused = false
	remaining = 0.0
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
	get_node("/root/Music").play_context("play")
	refresh_hud()
func refresh_hud() -> void:
	var allowed: bool = phase == "play" and not paused and result.is_empty() and not players[0].is_cpu
	var view := preload("res://scripts/ui/combat_hud_view.gd").capture(players[0],allowed)
	hud.present(view,{"paused":paused,"result":result,"sound_enabled":sound.enabled,
		"encounter_active":exploration.encounter_status == "active",
		"enemies_alive":players.slice(1).filter(func(player): return player.state.hp > 0).size()})
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
