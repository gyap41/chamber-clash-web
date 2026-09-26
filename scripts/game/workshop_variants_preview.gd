extends "res://scripts/game/exploration.gd"
# Review gallery: the same shapes, furniture rules and theme as random exploration.
const Variants = preload("res://scripts/world/workshop_room_variants.gd")
static func build_catalog() -> Dictionary:
	var rooms := {}
	for i in range(Variants.NORMAL_SHAPES.size()):
		var shape: String = Variants.NORMAL_SHAPES[i]
		var room = Variants.make_room(shape,["west","east"],shape)
		for prop in Floor.Layouts[i%2].placements:
			if prop.placement_id != "lamp_exit": Variants.place(room,prop,shape)
		preload("res://scripts/world/ashen_foundry_dressing.gd").apply(room,"normal",i)
		room.display_name = "%02d / %02d　%s" % [i+1,Variants.NORMAL_SHAPES.size(),Variants.SPECS[shape].name]
		for door in room.doors:
			var step := -1 if door.id == "west" else 1
			door.target_room = Variants.NORMAL_SHAPES[posmod(i+step,Variants.NORMAL_SHAPES.size())]
		rooms[shape] = room
	return rooms
func _ready() -> void:
	room_catalog = build_catalog()
	start_room = "west_annex"
	encounters_enabled = false
	preserve_room_dressing = true
	super._ready()
