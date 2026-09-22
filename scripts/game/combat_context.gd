extends Node2D
const Weapons = preload("res://scripts/catalog/weapon_catalog.gd")
const Catalog = preload("res://scripts/catalog/game_catalog.gd")
const Relics = preload("res://scripts/catalog/relic_catalog.gd")
const CpuAI = preload("res://scripts/ai/cpu_ai.gd")
const FieldDefinition = preload("res://scripts/world/field_definition.gd")
const Characters = preload("res://scripts/catalog/character_catalog.gd")
@export var pulse_effect_scene: PackedScene = preload("res://scenes/combat/pulse_effect.tscn")
@export var round_duration: float = 90.0
@export var projectile_scene: PackedScene = preload("res://scenes/combat/projectile.tscn")
@export var gravity_well_scene: PackedScene = preload("res://scenes/combat/gravity_well.tscn")
@onready var arena = $Arena
@onready var players: Array = $Arena/Players.get_children()
@onready var hud = $HUD
const Roster = preload("res://scripts/combat/battle_roster.gd")
const Command = preload("res://scripts/combat/combat_command.gd")
const HumanInput = preload("res://scripts/combat/human_input.gd")
const Victory = preload("res://scripts/combat/victory_rule.gd")
var roster = Roster.new()
var presentation = preload("res://scripts/combat/combat_events.gd").new()
var combat
var command_source: Callable
var battle_outcome: Dictionary = {}
var submitted_commands: Dictionary = {}
var participant_config: Array = []
var fighters: Array = [] # State views retained for the original regression API.
var shots: Array = []
var wells: Array = []
var pulse_effects: Array = []
var remaining: float
var result := ""
var paused := false
var mouse_fire_held := false
var catalog: Dictionary
const RunLog = preload("res://scripts/game/run_log.gd")
var telemetry
var supply_generator
var phase := "prepare"
var scores := [0, 0]
var delayed_shots: Array = []
var volley_counter := 0
var origin_counter := 0
@onready var supplies = $Arena/Supplies
@onready var combat_visuals = $Arena/CombatVisuals
@onready var sound = $Sound
# Shared runtime contract for duel and exploration; no MatchState or preparation UI.
func initialize_combat_context() -> void:
	catalog = Catalog.data
	if participant_config.is_empty():
		for i in range(players.size()): participant_config.append({"id":"p%d" % (i+1),"team":"team%d" % i,"controller":"human" if i == 0 else "cpu"})
	roster.configure(participant_config)
	assert(players.size() == roster.participants.size())
	presentation.emitted.connect(_present_event)
	command_source = resolve_command
	combat = preload("res://scripts/combat/combat_session.gd").new(self)
	fit_field_camera()
	supplies.game = self
	for i in range(players.size()): bind_combat_actor(i)

# Called once per newly registered actor, only outside a simulation step.
func bind_combat_actor(i: int) -> void:
	var player = players[i]
	player.combat_service = weakref(combat)
	player.participant_id = roster.participants[i].id
	player.team_id = roster.participants[i].team
	player.battle_slot = i
	player.battle_roster = roster
	player.is_cpu = roster.participants[i].controller == "cpu"
	player.weapon_event_requested.connect(presentation.weapon_event)
	player.burst_requested.connect(presentation.burst)
	player.ring_requested.connect(presentation.ring)
	player.shake_requested.connect(presentation.shake)
	player.sound_requested.connect(presentation.play_sound)
	# 残響ホルスター: Player has no back-reference to main.gd, so it asks for a delayed
	# shot via signal instead; bind the owning index since the signal itself only carries
	# the spawn data.
	player.delayed_shot_requested.connect(_on_delayed_shot_requested.bind(i))

func arena_inset() -> float:
	return 0.0

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		mouse_fire_held = false
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		mouse_fire_held = phase == "play" and not paused and result == ""
		if mouse_fire_held and not players[0].is_cpu: apply_command(0,{"fire_pressed":true})
	# P1's melee is a right-click (mouse-driven control scheme, 2026-09-08) rather than a
	# keyboard key; it does not go through handle_key()/_unhandled_key_input at all.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		if phase == "play" and not paused and result == "" and not players[0].is_cpu:
			apply_command(0,{"melee":true})
	# マウスホイールでのP1武器切替（2026-09-10追加）：Eキー・1〜4キーの既存経路には手を
	# 入れず、追加の入力経路として実装。ガード条件はEキーの巡回切替と同一
	# （phase=="play" かつ非ポーズ・非決着・非CPU）。P2はこの入力を一切参照しない。
	if event is InputEventMouseButton and event.pressed and not players[0].is_cpu:
		if phase == "play" and not paused and result == "":
			var p0 = players[0]
			# P8z ステップA：丸腰（inventoryが空）だと剰余がゼロ除算になるため、切替自体を無視する。
			var inv_size: int = p0.inventory.size()
			if inv_size > 0:
				if event.button_index == MOUSE_BUTTON_WHEEL_UP:
					apply_command(0,{"switch":(p0.switch_selection()+1) % inv_size})
				elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
					apply_command(0,{"switch":(p0.switch_selection()-1+inv_size) % inv_size})
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT: clear_action_inputs()
func clear_action_inputs() -> void:
	mouse_fire_held = false
	submitted_commands.clear()
	for player in players: player.clear_action_inputs()
func apply_command(index: int, command: Dictionary) -> void:
	combat.apply_command(index,command)
func submit_command(participant_id: String, command: Dictionary) -> bool:
	for i in range(roster.participants.size()):
		if roster.participants[i].id == participant_id:
			var accepted := Command.idle(players[i].state.angle)
			for key in accepted:
				if command.has(key): accepted[key] = command[key]
			submitted_commands[i] = accepted
			return true
	return false
func use_pulse(index: int) -> bool:
	return combat.use_pulse(index)
func _on_delayed_shot_requested(data: Dictionary, owner_index: int) -> void:
	return combat._on_delayed_shot_requested(data,owner_index)
func _on_projectile_derived_shot(owner_index: int, pos: Vector2, relic_id: int) -> void:
	return combat._on_projectile_derived_shot(owner_index,pos,relic_id)
func fire(index: int) -> void:
	return combat.fire(index)
func spawn_shot(index: int, id: int, angle: float, opts: Dictionary = {}) -> void:
	return combat.spawn_shot(index,id,angle,opts)
func spawn_well(pos: Vector2, owner_index: int):
	return combat.spawn_well(pos,owner_index)
func equip_slot(index: int, slot: int) -> void:
	if phase == "play" and not paused and result == "" and not players[index].is_cpu: apply_command(index,{"switch":slot})
# Danger zone: the safe area starts shrinking 60s into the round (7px/sec, capped at 195px
# inset from each wall) and never shrinks back. Matches the legacy web version's arenaInset().
func move_fighter(p: Dictionary, delta: Vector2) -> void:
	arena.move_fighter(p,delta)
func _step_pulse_effects(dt: float) -> void:
	for n in range(pulse_effects.size()-1,-1,-1):
		if pulse_effects[n].step(dt):
			var effect = pulse_effects.pop_at(n)
			effect.get_parent().remove_child(effect)
			effect.queue_free()

func _step_delayed_shots(dt: float) -> void:
	return combat._step_delayed_shots(dt)
func _step_players(dt: float) -> void:
	combat._step_players(dt)
func _step_projectiles(dt: float) -> void:
	return combat._step_projectiles(dt)
func _step_wells(dt: float) -> void:
	return combat._step_wells(dt)
func _process(dt: float) -> void:
	get_node("/root/Music").set_ducked(paused)
	if phase == "play" and not paused and result == "" and telemetry != null:
		telemetry.frame(dt,shots.size())

# Result navigation starts a fresh selection/match and releases the entire battle scene.
func _present_event(kind: String, args: Array) -> void:
	if kind == "sound": sound.play_sound.callv(args)
	elif kind == "pulse":
		var effect = pulse_effect_scene.instantiate()
		arena.get_node("Effects").add_child(effect)
		effect.position = args[0]
		effect.modulate = Color("f39545") if args[1] == 0 else Color("64b5ee")
		pulse_effects.append(effect)
	else: combat_visuals.callv(kind,args)

func resolve_command(i: int, dt: float) -> Dictionary:
	var player = players[i]
	var enemy = roster.nearest(i,players,player.state.pos)
	var command: Dictionary
	if submitted_commands.has(i):
		command = submitted_commands[i]
		submitted_commands.erase(i)
	elif player.is_cpu: command = CpuAI.sample(self,player,enemy,dt)
	elif i == 0 and roster.participants[i].controller == "human": command = HumanInput.sample(player,mouse_fire_held)
	else: command = Command.idle(player.state.angle)
	return command

func clear_field_objects() -> void:
	supplies.reset()
	for effect in pulse_effects:
		effect.get_parent().remove_child(effect)
		effect.queue_free()
	pulse_effects.clear()
	for well in wells:
		well.get_parent().remove_child(well)
		well.queue_free()
	wells.clear()
	for b in shots:
		b.get_parent().remove_child(b)
		b.queue_free()
	shots.clear()
	delayed_shots.clear()

func fit_field_camera() -> void:
	var scale_factor: float = minf(1120.0/arena.field_rect.size.x,600.0/arena.field_rect.size.y)
	var camera = arena.get_node("CombatCamera")
	camera.zoom = Vector2.ONE*scale_factor
	camera.position = arena.field_rect.position-Vector2((1120.0/scale_factor-arena.field_rect.size.x)*.5,90.0/scale_factor)
	camera.offset = Vector2.ZERO

func refresh_hud() -> void:
	hud.refresh(players,remaining,paused,result,scores,phase)

# Geometry replacement is synchronous. Failure leaves the current field and battle intact.
# A room transition keeps actor resources/timers; an encounter boundary resets only transient
# actor state through begin_encounter. Neither policy restarts the match or grants resources.
func switch_field(definition: FieldDefinition, new_encounter: bool = false) -> PackedStringArray:
	var radius := 14.0
	for player in players: radius = maxf(radius,player.radius)
	var errors: PackedStringArray = arena.configure_field(definition,players.size(),radius)
	if not errors.is_empty(): return errors
	clear_field_objects()
	clear_action_inputs()
	combat_visuals.clear()
	for i in range(players.size()):
		var player = players[i]
		if new_encounter: player.begin_encounter(arena.spawn_position(i))
		else: player.move_to_room(arena.spawn_position(i))
		# Cached routes and observed enemy positions belong to the old geometry.
		for key in player.state.keys():
			if str(key).begins_with("ai_") and key != "ai_cd": player.state.erase(key)
		fighters[i] = player.state
	fit_field_camera()
	arena.get_node("DangerZone").refresh(arena_inset() if phase in ["play","result"] else 0.0)
	refresh_hud()
	return errors
