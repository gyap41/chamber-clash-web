extends SceneTree
const Door = preload("res://scripts/world/exploration_door.gd")
const Sound = preload("res://scripts/audio/sound.gd")
var events: Array[String] = []
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	assert(Sound.gate_streams.size() == 2)
	assert(Sound.gate_streams.gate_close.resource_path == "res://assets/audio/se/fw_gate_close_heavy_02.wav")
	assert(Sound.gate_streams.gate_open.resource_path == "res://assets/audio/se/fw_gate_open_heavy_02.wav")
	var adopted: Dictionary = Sound.gate_streams.duplicate()
	var sound := Sound.new()
	root.add_child(sound)
	# Fixtures verify event semantics independently of optional paid candidates.
	Sound.gate_streams = {"gate_close":Sound.GENERATED.chest_open,"gate_open":Sound.GENERATED.chest_open}
	sound.played.connect(func(kind: String, _id: int) -> void: events.append(kind))
	var doors: Array = []
	for i in range(4):
		var door := Door.new()
		root.add_child(door)
		door.motion_started.connect(sound.play_gate)
		doors.append(door)
		door.step(.1)
	assert(events.is_empty()) # Initial/revisited open room is silent.
	for door in doors:
		door.set_locked(true)
		door.step(.1)
	assert(events == ["gate_close"]) # Four simultaneous exits, one room sound.
	for door in doors: door.step(.1)
	assert(events.size() == 1)
	sound.pause_boss_audio(true)
	assert(sound.gate_voice.stream_paused)
	sound.pause_boss_audio(false)
	assert(not sound.gate_voice.stream_paused)
	for door in doors:
		door.set_locked(false)
		door.step(.05)
	assert(events == ["gate_close","gate_open"])
	assert(sound.gate_kind == "gate_open") # Reversal replaces the closing voice.
	sound.set_enabled(false)
	assert(not sound.gate_voice.playing and sound.gate_voice.stream == null)
	for door in doors:
		door.set_locked(true)
		door.step(.35)
	assert(events.size() == 2)
	sound.enabled = true
	sound.play_gate("gate_open")
	sound.stop_gate()
	assert(sound.gate_voice.stream == null and sound.gate_frame == -1)
	for door in doors: door.free()
	Sound.gate_streams = adopted
	sound.free()
	print("PASS: gate motion onset, coalescing, reversal, pause, mute and room cleanup")
	quit()
