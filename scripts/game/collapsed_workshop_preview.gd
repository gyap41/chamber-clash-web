extends "res://scripts/game/exploration.gd"

func _ready() -> void:
	room_catalog = preload("res://scripts/world/collapsed_workshop_demo.gd").catalog()
	start_room = "collapsed_workshop"
	encounters_enabled = false
	preserve_room_dressing = true
	super._ready()
