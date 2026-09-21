extends "res://scripts/game/combat_context.gd"
const MatchState = preload("res://scripts/game/match_state.gd")
var match_state
@onready var preparation = $Preparation
func _ready() -> void:
	initialize_combat_context()
	preparation.game = self
	var seed_value := -1
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--seed="): seed_value = int(argument.trim_prefix("--seed="))
	new_match(seed_value)
func new_match(seed_value: int = -1) -> void:
	match_state = MatchState.new(seed_value if seed_value >= 0 else Time.get_ticks_usec(),players.size())
	# P8z：マッチを作り直しても、選んだキャラクターの初期武器から始められるようにする。初回は
	# キャラ未選択（char_id < 0）なのでMatchState側の既定の初期武器のままで、キャラ確定時に
	# assign_character()が差し替える。
	for i in range(players.size()):
		players[i].match_inventory = match_state
		players[i].match_player_index = i
		if players[i].char_id >= 0: match_state.grant_start_weapon(i,Characters.start_gun(players[i].char_id))
	supply_generator = MatchState.Generator.new(match_state.seed_value ^ 0x51A7)
	telemetry = RunLog.new(match_state.seed_value)
	scores = match_state.scores
	result = ""
	volley_counter = 0
	origin_counter = 0
	reset_round(false)
func reset_round(check_new: bool = true) -> void:
	if check_new and (match_state == null or result == "" or scores.max() >= MatchState.WIN_TARGET):
		new_match()
		return
	var replay: bool = result == "DRAW"
	combat_visuals.clear()
	arena.get_node("CombatCamera").offset = Vector2.ZERO
	mouse_fire_held = false
	# Audio preferences belong to the session, not the build.
	clear_field_objects()
	fighters.clear()
	for i in range(players.size()):
		players[i].reset(arena.spawn_position(i))
		players[i].telemetry = telemetry
		players[i].apply_build(match_state.builds[i],match_state.capacity(i),false,match_state.usable_cells(i))
		fighters.append(players[i].state)
	remaining = round_duration
	arena.get_node("DangerZone").refresh(0.0)
	result = ""
	battle_outcome = {}
	combat.reset_outcome()
	paused = false
	phase = "prepare"
	get_node("/root/Music").play_context("prepare")
	preparation.begin()
	if replay: launch_round()
	hud.refresh(players,remaining,paused,result,scores,phase)
# Release is observed before GUI handling; presses start fire only outside UI.
func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	if event.keycode == KEY_ENTER and result != "":
		advance_result()
		return
	if phase != "play": return
	if event.keycode == KEY_ESCAPE:
		paused = not paused
		clear_action_inputs()
	if paused or result != "": return
	if not players[0].is_cpu: apply_command(0,HumanInput.key(players[0],event.keycode))
func launch_round() -> void:
	if phase != "prepare" or not match_state.ready.all(func(value): return value): return
	mouse_fire_held = false
	phase = "play"
	get_node("/root/Music").play_context("play")
	for i in range(players.size()):
		players[i].reset(arena.spawn_position(i))
		players[i].apply_build(match_state.builds[i],match_state.capacity(i),true,match_state.usable_cells(i))
		fighters[i] = players[i].state
	match_state.start_round()
	telemetry.record("round_start",{"stage":match_state.stage,"builds":match_state.previous})
	supplies.launch()
	preparation.refresh()
# P8z：キャラクターの適用と初期武器の付与をまとめた入口。main.tscnの_ready()が先にnew_match()
# を走らせてしまうため、キャラが決まった時点でここを呼んで、初期武器を所持庫へ入れ直したビルドを
# プレイヤーへ反映する（scripts/ui/character_select.gdのstart_match()から呼ばれる）。
func assign_character(index: int, char_id: int) -> void:
	players[index].set_character(char_id)
	match_state.grant_start_weapon(index,Characters.start_gun(char_id))
	players[index].apply_build(match_state.builds[index],match_state.capacity(index),false,match_state.usable_cells(index))
func arena_inset() -> float:
	var elapsed: float = round_duration - remaining
	return 0.0 if elapsed <= 60.0 else minf(195.0,(elapsed-60.0)*7.0)
func _physics_process(dt: float) -> void:
	if phase == "play" and not paused and result == "":
		# Order matters: delayed shots precede player actions, projectile impacts precede
		# well absorption, and settlement observes all damage from this frame.
		combat_visuals.step(dt)
		_step_pulse_effects(dt)
		var previous_inset := arena_inset()
		combat.step(dt)
		if previous_inset <= 0 and arena_inset() > 0: sound.play_sound("danger_warning")
		_settle_round()
	arena.get_node("DangerZone").refresh(arena_inset() if phase in ["play","result"] else 0.0)
	arena.get_node("CombatCamera").offset = -combat_visuals.shake_offset
	hud.refresh(players,remaining,paused,result,scores,phase)

func _settle_round() -> void:
	if phase != "play" or not result.is_empty(): return
	var outcome: Dictionary = combat.outcome()
	if outcome.is_empty(): return
	battle_outcome = outcome
	result = "DRAW" if outcome.draw else ("P%d WINS" % (outcome.slots[0]+1) if players.size() == 2 else "TEAM %s WINS" % str(outcome.team))
	phase = "result"
	get_node("/root/Music").play_context("result")
	sound.stop_all()
	if remaining <= 0: sound.play_sound("time_up")
	sound.play_sound("draw" if outcome.draw else ("win" if 0 in outcome.slots else "lose"))
	delayed_shots.clear()
	clear_action_inputs()
	match_state.finish_team(outcome.slots,players)
	telemetry.record("round_end",{"result":result,"seconds":round_duration-remaining,"scores":scores,"outcome":outcome})

func advance_result() -> void:
	if result.is_empty() or is_queued_for_deletion(): return
	if scores.max() >= MatchState.WIN_TARGET:
		return_from_result(false)
	else:
		reset_round()

func return_from_result(to_title: bool) -> void:
	if result.is_empty() or scores.max() < MatchState.WIN_TARGET or is_queued_for_deletion(): return
	clear_action_inputs()
	set_physics_process(false)
	var next_scene = load("res://scenes/ui/title.tscn" if to_title else "res://scenes/ui/character_select.tscn").instantiate()
	if not to_title: next_scene.cpu_mode = true
	get_tree().root.add_child(next_scene)
	get_parent().remove_child(self)
	queue_free()
