extends Node
signal played(kind: String, id: int)
const Weapons = preload("res://scripts/catalog/weapon_catalog.gd")
const RATE := 44100
const GENERATED := {
	"workshop_open": preload("res://assets/audio/se/fw_workshop_open_energy_01.wav"),
	"aurora_divine": preload("res://assets/audio/se/fw_aurora_divine_03.mp3"),
	"machine_ram_launch": preload("res://assets/audio/se/fw_ash_ram_launch_02.mp3"),
	"machine_ring_salvo": preload("res://assets/audio/se/fw_triple_ring_salvo_02.mp3"),
	"enemy_defeat": preload("res://assets/audio/se/fw_enemy_defeat_01.mp3"),
	"moss_dash": preload("res://assets/audio/se/fw_moss_dash_03.mp3"),
	"moss_wall": preload("res://assets/audio/se/fw_moss_impact_01.mp3"),
	"moss_down": preload("res://assets/audio/se/fw_moss_down_01.mp3"),
	"boss_salvo": preload("res://assets/audio/se/fw_spinner_salvo_02.mp3"),
	"boss_cannon": preload("res://assets/audio/se/fw_spinner_main_cannon_01.mp3"),
	"boss_shell_impact": preload("res://assets/audio/se/fw_spinner_shell_impact_01.mp3"),
	"boss_heavy_impact": preload("res://assets/audio/se/fw_spinner_heavy_impact_01.mp3"),
	"boss_dash": preload("res://assets/audio/se/fw_spinner_dash_03.mp3"),
	"boss_impact": preload("res://assets/audio/se/fw_spinner_impact_01.mp3"),
	"boss_overdrive": preload("res://assets/audio/se/fw_spinner_overdrive_01.mp3"),
	"boss_vent": preload("res://assets/audio/se/fw_spinner_pressure_hiss_01.mp3"),
	"boss_internal": preload("res://assets/audio/se/fw_spinner_internal_blast_01.mp3"),
	"boss_explosion": preload("res://assets/audio/se/fw_spinner_explosion_01.mp3"),
	"sentry_swing": preload("res://assets/audio/se/fw_sentry_swing_01.mp3"),
	"sentry_down": preload("res://assets/audio/se/fw_sentry_down_01.mp3"),
	"quill_windup": preload("res://assets/audio/se/fw_quill_windup_01.mp3"),
	"quill_fire": preload("res://assets/audio/se/fw_quill_fire_01.mp3"),
	"quill_down": preload("res://assets/audio/se/fw_quill_down_01.mp3"),
	"lizard_down": preload("res://assets/audio/se/fw_lizard_down_01.mp3"),
	"sentry_windup": preload("res://assets/audio/se/fw_sentry_windup_01.mp3"),
	"lizard_inhale": preload("res://assets/audio/se/fw_lizard_inhale_01.mp3"),
	"lizard_spit": preload("res://assets/audio/se/fw_lizard_spit_03.mp3"),
	"shotgun": preload("res://assets/audio/se/fw_shotgun_01.mp3"),
	"needle": preload("res://assets/audio/se/fw_needle_01.mp3"),
	"metal_shot": preload("res://assets/audio/se/fw_metal_shot_01.mp3"),
	"launcher": preload("res://assets/audio/se/fw_launcher_01.mp3"),
	"return_blade": preload("res://assets/audio/se/fw_return_blade_01.mp3"),
	"seed_launch": preload("res://assets/audio/se/fw_seed_launch_01.mp3"),
	"pressure_ball": preload("res://assets/audio/se/fw_pressure_ball_01.mp3"),
	"sheet_launch": preload("res://assets/audio/se/fw_sheet_launch_01.mp3"),
	"tool_switch_shot": preload("res://assets/audio/se/fw_tool_switch_shot_01.mp3"),
	"ancient_shot": preload("res://assets/audio/se/fw_ancient_shot_01.mp3"),
	"wall_impact": preload("res://assets/audio/se/fw_wall_impact_01.mp3"),
	"ricochet": preload("res://assets/audio/se/fw_ricochet_01.mp3"),
	"explosion": preload("res://assets/audio/se/fw_explosion_01.mp3"),
	"melee_clear": preload("res://assets/audio/se/fw_melee_clear_01.mp3"),
	"heavy_dodge": preload("res://assets/audio/se/fw_heavy_dodge_01.mp3"),
	"landing": preload("res://assets/audio/se/fw_landing_01.mp3"),
	"power_reload": preload("res://assets/audio/se/fw_power_reload_01.mp3"),
	"heal": preload("res://assets/audio/se/fw_heal_01.mp3"),
	"gravity": preload("res://assets/audio/se/fw_gravity_01.mp3"),
	"ui_remove": preload("res://assets/audio/se/fw_ui_remove_01.mp3"),
	"ui_sell": preload("res://assets/audio/se/fw_ui_sell_01.mp3"),
	"ui_expand": preload("res://assets/audio/se/fw_ui_expand_01.mp3"),
	"chest_open": preload("res://assets/audio/se/fw_chest_open_01.mp3"),
	"ammo_pickup": preload("res://assets/audio/se/fw_ammo_pickup_01.mp3"),
	"rare_pickup": preload("res://assets/audio/se/fw_rare_pickup_01.mp3"),
	"draw": preload("res://assets/audio/se/fw_draw_01.mp3"),
	"time_up": preload("res://assets/audio/se/fw_time_up_01.mp3"),
	"slash": preload("res://assets/audio/se/fw_melee_swing_01.mp3"),
	"equip": preload("res://assets/audio/se/fw_weapon_switch_01.mp3"),
	"bell": preload("res://assets/audio/se/fw_defense_01.mp3"),
	"pickup": preload("res://assets/audio/se/fw_item_pickup_01.mp3"),
	"legendary": preload("res://assets/audio/se/fw_rare_drop_02.mp3"),
	"danger_warning": preload("res://assets/audio/se/fw_danger_warning_02.mp3"),
	"chest_spawn": preload("res://assets/audio/se/fw_chest_spawn_01.mp3"),

	"pistol": preload("res://assets/audio/se/fw_pistol_short_01.mp3"),
	"heavy": preload("res://assets/audio/se/fw_heavy_short_01.mp3"),
	"rapid": preload("res://assets/audio/se/fw_rapid_short_01.mp3"),
	"energy": preload("res://assets/audio/se/fw_energy_short_01.mp3"),
	"hit": preload("res://assets/audio/se/fw_hit_short_01.mp3"),
	"dodge": preload("res://assets/audio/se/fw_dodge_short_01.mp3"),
	"reload": preload("res://assets/audio/se/fw_reload_short_01.mp3"),
	"boom": preload("res://assets/audio/se/fw_pulse_short_01.mp3"),
	"ui_select": preload("res://assets/audio/se/fw_ui_select_short_01.mp3"),
	"ui_confirm": preload("res://assets/audio/se/fw_ui_confirm_short_01.mp3"),
	"ui_cancel": preload("res://assets/audio/se/fw_ui_cancel_short_01.mp3"),
	"ui_place": preload("res://assets/audio/se/fw_ui_place_short_01.mp3"),
	"ui_purchase": preload("res://assets/audio/se/fw_ui_purchase_short_01.mp3"),
	# Exploration event rooms (docs/art/production/event-rooms), generated 2026-10-01.
	"coin": preload("res://assets/audio/se/fw_coin_pickup_01.mp3"),
	"teleport": preload("res://assets/audio/se/fw_teleport_01.mp3"),
	"altar_offer": preload("res://assets/audio/se/fw_altar_offer_01.mp3"),
	"challenge_start": preload("res://assets/audio/se/fw_challenge_start_01.mp3"),
	"ui_blocked": preload("res://assets/audio/se/fw_ui_blocked_short_01.mp3"),
	"win": preload("res://assets/audio/se/fw_victory_short_01.mp3"),
	"lose": preload("res://assets/audio/se/fw_defeat_short_01.mp3")
}
@export var enabled := true
@export_range(-40,0) var volume_db := 0.0
var voices: Array[AudioStreamPlayer] = []
var cache: Dictionary = {}
var next_voice := 0
var contact_times: Dictionary = {}
var bus_name: String
var rng := RandomNumberGenerator.new()
var boss_engine: AudioStreamPlayer
var moss_rollers: Dictionary = {}
var moss_paused := false
# 2026-10-07: approved heavy iron mix, unchanged from audio candidate v2.
static var gate_streams: Dictionary = {
	"gate_close":preload("res://assets/audio/se/fw_gate_close_heavy_02.wav"),
	"gate_open":preload("res://assets/audio/se/fw_gate_open_heavy_02.wav")}
var gate_voice: AudioStreamPlayer
var gate_frame: int = -1
var gate_kind: String = ""

func _ready() -> void:
	rng.randomize()
	bus_name = "ChamberSFX_"+str(get_instance_id())
	AudioServer.add_bus()
	var index := AudioServer.bus_count-1
	AudioServer.set_bus_name(index,bus_name)
	AudioServer.set_bus_send(index,"Master")
	var compressor := AudioEffectCompressor.new()
	compressor.threshold = -18.0
	compressor.ratio = 5.0
	AudioServer.add_bus_effect(index,compressor)
	gate_voice = AudioStreamPlayer.new()
	gate_voice.bus = bus_name
	gate_voice.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
	add_child(gate_voice)
	boss_engine = AudioStreamPlayer.new()
	boss_engine.stream = preload("res://assets/audio/se/fw_spinner_engine_loop_01.mp3").duplicate()
	boss_engine.stream.loop = true
	boss_engine.bus = bus_name
	boss_engine.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
	add_child(boss_engine)
	for i in range(16):
		var voice := AudioStreamPlayer.new()
		# Keep generated/synthesized audio and the compressor on the same mixer on Web.
		voice.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
		add_child(voice)
		voices.append(voice)

func _exit_tree() -> void:
	stop_all()
	cache.clear()
	var index := AudioServer.get_bus_index(bus_name)
	if index > 0: AudioServer.remove_bus(index)

func stop_all(keep_boss_death: bool = false) -> void:
	stop_gate()
	for owner in moss_rollers.keys(): stop_moss_roll(owner)
	if is_instance_valid(boss_engine): boss_engine.stop()
	for voice in voices:
		if keep_boss_death and voice.get_meta("kind","") in ["boss_internal","boss_explosion"]: continue
		voice.stop()
		voice.stream = null

func update_boss_engine(active: bool, distance: float = 0.0, intensity: float = 0.0) -> void:
	if not enabled or not active or distance >= 850:
		boss_engine.stop()
		return
	boss_engine.volume_db = volume_db-30.0-clampf(distance/850.0,0,1)*18.0
	boss_engine.pitch_scale = 1.0+clampf(intensity,0,1)*.18
	if not boss_engine.playing: boss_engine.play()

func pause_boss_audio(value: bool) -> void:
	if is_instance_valid(gate_voice): gate_voice.stream_paused = value
	moss_paused=value
	for roller in moss_rollers.values(): roller.stream_paused=value
	boss_engine.stream_paused = value
	for voice in voices:
		if str(voice.get_meta("kind","")).begins_with("boss_") or str(voice.get_meta("kind","")).begins_with("moss_") or str(voice.get_meta("kind","")).begins_with("machine_"): voice.stream_paused = value

func set_enabled(value: bool) -> void:
	enabled = value
	if not enabled: stop_all()
	else: play_sound("toggle")

func stop_gate() -> void:
	if is_instance_valid(gate_voice):
		gate_voice.stop()
		gate_voice.stream = null
	gate_frame = -1
	gate_kind = ""

func play_gate(kind: String, remaining_seconds: float = -1.0) -> void:
	if not enabled or not gate_streams.has(kind): return
	# All exits animate together. One room voice avoids four overlapping slams;
	# reversing replaces the old motion sound instead of leaving its tail running.
	var frame: int = Engine.get_process_frames()
	if gate_frame == frame and gate_kind == kind: return
	gate_frame = frame
	gate_kind = kind
	gate_voice.stop()
	gate_voice.stream = gate_streams[kind]
	gate_voice.stream_paused = moss_paused
	gate_voice.volume_db = volume_db+(-20.0 if kind == "gate_close" else -19.0)
	var motion_length: float = .35 if kind == "gate_close" else .65
	var seek: float = maxf(0.0,motion_length-remaining_seconds) if remaining_seconds >= 0 else 0.0
	gate_voice.play(seek)
	played.emit(kind,0)

func profile(kind: String, id: int = 0) -> Dictionary:
	# 2026-10-05: opening uses the adopted mixed asset; closing remains unchanged.
	if kind=="workshop_close":
		return {"duration":.20,"frequency":300.0,"end":75.0,"wave":"sine","gain":.035,"noise":.02,"cutoff":1400.0,"bandpass":false,"soft_edges":true,"metallic":true,"harmonics":false}
	if kind in ["machine_ram_windup","machine_ring_windup","machine_vent","machine_ram_body","machine_ring_body"]:
		var vent := kind == "machine_vent"
		var ram := kind in ["machine_ram_windup","machine_ram_body"]
		var body := kind in ["machine_ram_body","machine_ring_body"]
		return {"duration":.22 if vent else .18 if body else .38,"frequency":100.0 if ram else 160.0,"end":55.0 if vent or body else 145.0 if ram else 220.0,"wave":"sine","gain":.018 if vent else .065,"noise":.045 if vent else .016,"cutoff":1600.0 if vent else 900.0,"bandpass":false,"soft_edges":true,"metallic":not vent}
	if kind == "shot" and id == 37:
		return {"duration":.32,"frequency":880.0,"end":520.0,"wave":"sine","gain":.08,"noise":.018,"cutoff":6200.0,"bandpass":true,"harmonics":true,"shimmer":true,"soft_edges":true}
	if kind in ["moss_curl","moss_roll","moss_contact"]:
		return {"duration":.10 if kind=="moss_roll" else .18,"frequency":95.0 if kind=="moss_contact" else 65.0,"end":35.0,"wave":"sine","gain":.045 if kind=="moss_contact" else .006,"noise":.05 if kind=="moss_curl" else .018,"cutoff":750.0 if kind=="moss_curl" else 340.0,"bandpass":false}
	var tones := {"equip":[200,.06],"bell":[700,.14],"pickup":[640,.18],"start":[530,.18],"legendary":[850,.3],"win":[650,.3],"lose":[280,.3],"toggle":[500,.06],"gravity":[100,.3]}
	if tones.has(kind):
		var tone: Array = tones[kind]
		return {"duration":tone[1],"frequency":tone[0],"end":float(tone[0])*.45,"wave":"sine" if kind == "gravity" else "triangle","gain":.025,"noise":0.0,"cutoff":200.0,"bandpass":false}
	var g: Dictionary = Weapons.definition(id)
	var energy: bool = g.get("rail",false) or g.get("gravity",false) or g.get("prism",false)
	var heavy: bool = g.get("comet",false) or g.type == "SHOTGUN"
	return {"duration":.4 if kind == "boom" else ((.2 if heavy else .16 if energy else .09) if kind == "shot" else .1 if kind == "reload" else .12),
		"frequency":90.0 if kind == "boom" else 220.0 if kind == "reload" else 1100.0 if energy else 150.0 if heavy else 240.0,
		"end":25.0 if kind == "boom" else 130.0 if energy else 45.0,
		"wave":"sawtooth" if energy and kind == "shot" else "triangle","gain":.07,
		"noise":.22 if kind == "boom" else .12 if kind == "shot" else .065,
		"cutoff":3600.0 if kind == "reload" else 650.0 if kind == "boom" else 1800.0 if heavy else 4500.0 if energy else 2700.0,
		"bandpass":energy and kind == "shot"}

func synthesize(p: Dictionary) -> AudioStreamWAV:
	var count := int(ceil(float(p.duration)*RATE))
	var bytes := PackedByteArray()
	bytes.resize(count*2)
	var phase := 0.0
	var x1 := 0.0
	var x2 := 0.0
	var y1 := 0.0
	var y2 := 0.0
	for i in range(count):
		var progress := float(i)/count
		var frequency: float = p.frequency*pow(p.end/p.frequency,progress)
		var wave: float = sin(phase*TAU) if p.wave == "sine" else (2.0*(phase-floorf(phase+.5)) if p.wave == "sawtooth" else 2.0/PI*asin(sin(phase*TAU)))
		if p.get("harmonics",false): wave += .45*sin(phase*TAU*1.5)+.25*sin(phase*TAU*2.01)
		if p.get("metallic",false): wave += .38*sin(phase*TAU*2.73)+.22*sin(phase*TAU*4.17)
		phase += frequency/RATE
		var value: float = wave*p.gain*pow(.001/p.gain,progress)
		if p.noise > 0:
			# Swept biquad, Q=1; WebAudio/Godot DSP are not sample-identical.
			var omega: float = TAU*p.cutoff*pow(200.0/p.cutoff,progress)/RATE
			var c := cos(omega)
			var alpha := sin(omega)/2.0
			var b0: float = alpha if p.bandpass else (1.0-c)/2.0
			var b1: float = 0.0 if p.bandpass else 1.0-c
			var b2: float = -alpha if p.bandpass else b0
			var x := rng.randf_range(-1,1)
			var y := (b0*x+b1*x1+b2*x2+2*c*y1-(1-alpha)*y2)/(1+alpha)
			x2 = x1
			x1 = x
			y2 = y1
			y1 = y
			value += y*p.noise*pow(.001/p.noise,progress)
		if p.get("shimmer",false):
			var seconds := float(i)/RATE
			for n in range(3):
				var age: float = seconds-n*.035
				if age >= 0:
					value += sin(TAU*(1320+n*330)*age)*.018*exp(-age*24)*minf(1,age/.004)
		if p.get("soft_edges",false): value *= minf(1,float(i)/maxf(1,RATE*.004))*minf(1,float(count-1-i)/maxf(1,RATE*.012))
		bytes.encode_s16(i*2,int(clampf(value,-1,1)*32767))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.data = bytes
	return stream

func play_chest_open(rank: int) -> void:
	play_sound("chest_open_tier",clampi(rank,0,3))
	if rank >= 2: play_sound("chest_reward_tier",clampi(rank,0,3))

func play_sound(kind: String, id: int = 0) -> void:
	if kind == "workshop_stop":
		for voice in voices:
			if voice.get_meta("owner",-1)==id and str(voice.get_meta("kind","")).begins_with("workshop_"): voice.stop()
		return
	if kind == "machine_stop":
		for voice in voices:
			if voice.get_meta("owner",-1)==id and str(voice.get_meta("kind","")).begins_with("machine_"): voice.stop()
		return
	if kind=="moss_stop":
		stop_moss_roll(id)
		for voice in voices:
			if voice.get_meta("owner",-1)==id and voice.get_meta("kind","") in ["moss_roll","moss_dash","moss_curl"]: voice.stop()
		return
	if not enabled or kind == "start": return
	if kind in ["moss_roll","moss_roll_low"]:
		update_moss_roll(id,.82 if kind=="moss_roll_low" else 1.12)
		return
	# Coalesce simultaneous pellet impacts without changing projectile simulation.
	if kind in ["machine_ram_launch","machine_ring_salvo","machine_ram_windup","machine_ring_windup","machine_vent","enemy_defeat","moss_dash","moss_wall","moss_down","moss_curl","moss_roll","moss_contact","boss_shell_impact","boss_heavy_impact","wall_impact","ricochet","sentry_windup","lizard_inhale","sentry_swing","lizard_spit","sentry_down","lizard_down","quill_windup","quill_fire","quill_down"]:
		var now := Time.get_ticks_msec()
		var interval := 100 if kind.begins_with("boss_") else 200 if kind == "wall_impact" else 120 if kind == "ricochet" else 60
		var throttle_key := kind+"/"+str(id) if kind in ["moss_dash","moss_curl"] else kind
		if now-int(contact_times.get(throttle_key,-1000)) < interval: return
		contact_times[throttle_key] = now
	var sample := sample_key(kind,id)
	if not sample.is_empty():
		var generated_voice := voices[next_voice]
		next_voice = (next_voice+1)%voices.size()
		generated_voice.stop()
		generated_voice.stream_paused = false
		generated_voice.pitch_scale = 1.0
		generated_voice.set_meta("kind",kind)
		generated_voice.set_meta("owner",id)
		generated_voice.bus = bus_name
		generated_voice.volume_db = volume_db + (-18.0 if kind.begins_with("ui_") or kind == "toggle" else -12.0)
		# The accepted mix already contains the audition gains; do not attenuate twice.
		if kind=="workshop_open": generated_voice.volume_db = volume_db
		if kind == "machine_ram_launch": generated_voice.volume_db = volume_db-7.0
		elif kind == "machine_ring_salvo": generated_voice.volume_db = volume_db+2.0
		elif kind == "shot" and id == 37: generated_voice.volume_db = volume_db-18.0
		elif kind=="enemy_defeat": generated_voice.volume_db -= 5.0
		elif kind.begins_with("moss_"): generated_voice.volume_db -= 2.0 if kind=="moss_dash" else 5.0
		elif kind == "wall_impact": generated_voice.volume_db -= 12.0
		elif kind == "coin": generated_voice.volume_db -= 6.0 # Frequent: kept under combat sounds.
		elif kind == "ricochet": generated_voice.volume_db -= 8.0
		elif kind in ["sentry_windup","lizard_inhale","quill_windup"]: generated_voice.volume_db -= 3.0
		elif kind in ["sentry_swing","lizard_spit","quill_fire"]: generated_voice.volume_db += 2.0
		elif kind in ["sentry_down","lizard_down","quill_down"]: generated_voice.volume_db -= 3.0
		elif kind in ["boss_dash","boss_impact","boss_overdrive","boss_salvo","boss_cannon","boss_heavy_impact"]: generated_voice.volume_db -= 4.0
		elif kind in ["boss_vent","boss_internal","boss_shell_impact"]: generated_voice.volume_db -= 8.0
		generated_voice.stream = GENERATED[sample]
		if kind == "shot" and id != 37: generated_voice.pitch_scale = pow(2.0,float(id%7-3)/24.0)
		if kind == "chest_open_tier":
			generated_voice.pitch_scale = [1.08,1.0,.9,.8][clampi(id,0,3)]
			generated_voice.volume_db = volume_db+[-15.0,-14.0,-13.0,-12.0][clampi(id,0,3)]
		elif kind == "chest_reward_tier": generated_voice.volume_db = volume_db-19.0
		generated_voice.play()
		played.emit(kind,id)
		if kind == "machine_ram_launch": play_sound("machine_ram_body",id)
		elif kind == "machine_ring_salvo": play_sound("machine_ring_body",id)
		return
	var p := profile(kind,id)
	var key := str(p)
	if not cache.has(key): cache[key] = synthesize(p)
	var voice := voices[next_voice]
	next_voice = (next_voice+1)%voices.size()
	voice.stop()
	voice.stream_paused = false
	voice.pitch_scale = 1.0
	voice.set_meta("kind",kind)
	voice.set_meta("owner",id)
	voice.bus = bus_name if p.noise > 0 else "Master"
	voice.volume_db = volume_db
	voice.stream = cache[key]
	voice.play()
	played.emit(kind,id)

func sample_key(kind: String, id: int = 0) -> String:
	if kind == "chest_open_tier": return "chest_open"
	if kind == "chest_reward_tier": return "legendary" if id >= 3 else "rare_pickup"
	if kind == "shot":
		if id == 37: return "aurora_divine"
		if id in [0,20]: return "pistol"
		if id in [23,26]: return "heavy"
		if id in [19,27,28]: return "rapid"
		if id in [3,6,7,36]: return "energy"
		if id in [4, 31]: return "shotgun"
		if id in [21, 24, 29, 30]: return "needle"
		if id in [1, 22, 32]: return "metal_shot"
		if id in [2, 9, 12, 34]: return "launcher"
		if id in [5, 33]: return "return_blade"
		if id in [11, 14, 35]: return "seed_launch"
		if id in [13]: return "pressure_ball"
		if id in [16, 17]: return "sheet_launch"
		if id in [18]: return "tool_switch_shot"
		if id in [8, 10, 15, 25, 37]: return "ancient_shot"
		return ""
	if kind == "reload" and preload("res://scripts/catalog/weapon_visual_catalog.gd").profile(id).get("reload_style","mechanical") in ["charge","rune"]: return "power_reload"
	if kind == "start": return ""
	if kind == "toggle": return "ui_confirm"
	return kind if GENERATED.has(kind) else ""

# Continuous rolling has its own bounded voices; gunshots cannot steal them.
func update_moss_roll(owner: int, pitch: float) -> void:
	if not moss_rollers.has(owner):
		if moss_rollers.size()>=6: return
		var roller:=AudioStreamPlayer.new()
		roller.stream=preload("res://assets/audio/se/fw_moss_spin_loop_03.mp3").duplicate()
		roller.stream.loop=true
		roller.bus=bus_name
		roller.playback_type=AudioServer.PLAYBACK_TYPE_STREAM
		roller.stream_paused=moss_paused
		add_child(roller)
		moss_rollers[owner]=roller
		roller.play()
		played.emit("moss_roll",owner)
	var voice: AudioStreamPlayer=moss_rollers[owner]
	voice.pitch_scale=pitch
	# Keep the combined rumble restrained at the six-enemy test limit.
	for roller in moss_rollers.values(): roller.volume_db=volume_db-22.0-3.0*log(float(moss_rollers.size()))/log(2.0)
func stop_moss_roll(owner: int) -> void:
	if not moss_rollers.has(owner): return
	var roller: AudioStreamPlayer=moss_rollers[owner]
	roller.stop()
	roller.queue_free()
	moss_rollers.erase(owner)
	contact_times.erase("moss_dash/"+str(owner))
	contact_times.erase("moss_curl/"+str(owner))
