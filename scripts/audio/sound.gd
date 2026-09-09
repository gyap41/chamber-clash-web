extends Node
signal played(kind: String, id: int)
const Weapons = preload("res://scripts/catalog/weapon_catalog.gd")
const RATE := 44100
@export var enabled := false
@export_range(-40,0) var volume_db := 0.0
var voices: Array[AudioStreamPlayer] = []
var cache: Dictionary = {}
var next_voice := 0
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
		add_child(voice)
		voices.append(voice)

func _exit_tree() -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if index > 0: AudioServer.remove_bus(index)

func stop_all() -> void:
	for voice in voices: voice.stop()

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
	if not enabled: return
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
