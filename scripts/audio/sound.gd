extends Node
signal played(kind: String, id: int)
const Weapons = preload("res://scripts/catalog/weapon_catalog.gd")
const RATE := 44100
const GENERATED := {
	"sentry_swing": preload("res://assets/audio/se/fw_sentry_swing_01.mp3"),
	"sentry_down": preload("res://assets/audio/se/fw_sentry_down_01.mp3"),
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

func stop_all() -> void:
	for voice in voices:
		voice.stop()
		voice.stream = null

func set_enabled(value: bool) -> void:
	enabled = value
	if not enabled: stop_all()
	else: play_sound("toggle")

func profile(kind: String, id: int = 0) -> Dictionary:
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
		bytes.encode_s16(i*2,int(clampf(value,-1,1)*32767))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.data = bytes
	return stream

func play_sound(kind: String, id: int = 0) -> void:
	if not enabled or kind == "start": return
	# Coalesce simultaneous pellet impacts without changing projectile simulation.
	if kind in ["wall_impact","ricochet","sentry_windup","lizard_inhale","sentry_swing","lizard_spit","sentry_down","lizard_down"]:
		var now := Time.get_ticks_msec()
		var interval := 200 if kind == "wall_impact" else 120 if kind == "ricochet" else 60
		if now-int(contact_times.get(kind,-1000)) < interval: return
		contact_times[kind] = now
	var sample := sample_key(kind,id)
	if not sample.is_empty():
		var generated_voice := voices[next_voice]
		next_voice = (next_voice+1)%voices.size()
		generated_voice.stop()
		generated_voice.bus = bus_name
		generated_voice.volume_db = volume_db + (-18.0 if kind.begins_with("ui_") or kind == "toggle" else -12.0)
		if kind == "wall_impact": generated_voice.volume_db -= 12.0
		elif kind == "ricochet": generated_voice.volume_db -= 8.0
		elif kind in ["sentry_windup","lizard_inhale"]: generated_voice.volume_db -= 6.0
		elif kind in ["sentry_swing","lizard_spit","sentry_down","lizard_down"]: generated_voice.volume_db -= 3.0
		generated_voice.stream = GENERATED[sample]
		generated_voice.play()
		played.emit(kind,id)
		return
	var p := profile(kind,id)
	var key := str(p)
	if not cache.has(key): cache[key] = synthesize(p)
	var voice := voices[next_voice]
	next_voice = (next_voice+1)%voices.size()
	voice.stop()
	voice.bus = bus_name if p.noise > 0 else "Master"
	voice.volume_db = volume_db
	voice.stream = cache[key]
	voice.play()
	played.emit(kind,id)

func sample_key(kind: String, id: int = 0) -> String:
	if kind == "shot":
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
