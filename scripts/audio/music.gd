extends Node
# One session-wide player keeps title music continuous across scene changes.
const TRACKS := {
	"title": preload("res://assets/audio/bgm/fw_title_02.wav"),
	"prepare": preload("res://assets/audio/bgm/fw_preparation_02.wav"),
	"play": preload("res://assets/audio/bgm/fw_battle_02.wav")
}
const LEVELS := {"title": -18.0, "prepare": -22.0, "play": -22.0}
# Provisional endpoints omit measured quiet tails; musical seams need listening.
const LOOP_SECONDS := {"title": 60.0, "prepare": 85.96, "play": 114.07}
var player: AudioStreamPlayer
var current_track := ""
var enabled := true
var ducked := false
var toggle: Button
var streams: Dictionary = {}

func _ready() -> void:
	player = AudioStreamPlayer.new()
	# Web Sample playback does not use Godot's normal mixer/stream lifecycle.
	player.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
	add_child(player)
	var controls := CanvasLayer.new()
	controls.layer = 20
	add_child(controls)
	toggle = Button.new()
	toggle.name = "MusicToggle"
	toggle.position = Vector2(1000, 764)
	toggle.size = Vector2(108, 30)
	toggle.focus_mode = Control.FOCUS_NONE
	toggle.pressed.connect(func(): set_enabled(not enabled))
	controls.add_child(toggle)
	_update_volume()
	toggle.hide()

func play_context(context: String) -> void:
	toggle.show()
	if not TRACKS.has(context):
		current_track = ""
		player.stop()
		return
	ducked = false
	if current_track != context:
		current_track = context
		if not streams.has(context):
			var stream: AudioStreamWAV = TRACKS[context].duplicate()
			stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
			stream.loop_begin = 0
			stream.loop_end = int(round(float(LOOP_SECONDS[context])*stream.mix_rate))
			streams[context] = stream
		player.stream = streams[context]
		player.play()
	elif not player.playing:
		player.play()
	_update_volume()

func set_enabled(value: bool) -> void:
	enabled = value
	_update_volume()

func set_ducked(value: bool) -> void:
	if ducked == value: return
	ducked = value
	_update_volume()

func _update_volume() -> void:
	player.stream_paused = not enabled
	player.volume_db = float(LEVELS.get(current_track, -22.0)) - (8.0 if ducked else 0.0)
	toggle.text = "BGM ON" if enabled else "BGM OFF"
