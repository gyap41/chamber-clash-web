extends RefCounted
# Single list of exploration enemy scripts. Encounters, the combat lab and the Visual Hub read
# from here, so adding an enemy means one entry instead of several parallel lists.
# The boss is separate: it only appears in the boss room.
const ENEMIES := {
	"ember_lizard":preload("res://scripts/combat/ember_lizard.gd"),
	"iron_quill":preload("res://scripts/combat/iron_quill.gd"),
	"ash_ram":preload("res://scripts/combat/ash_ram.gd"),
	"triple_ring":preload("res://scripts/combat/triple_ring.gd"),

	"workshop_sentry":preload("res://scripts/combat/exploration_enemy.gd"),
	"fire_pouch_lizard":preload("res://scripts/combat/fire_pouch_lizard.gd"),
	"quillback":preload("res://scripts/combat/quillback.gd"),
	"scatter_drone":preload("res://scripts/combat/scatter_drone.gd"),
	"runner_sentry":preload("res://scripts/combat/runner_sentry.gd"),
	"ram_sentry":preload("res://scripts/combat/ram_sentry.gd"),
	"ring_sentry":preload("res://scripts/combat/ring_sentry.gd"),
	"root_runner_prototype":preload("res://scripts/combat/root_runner_prototype.gd")}
const BOSS_ID := "furnace_warden"
const BOSS = preload("res://scripts/combat/furnace_warden.gd")

# Script for an enemy id; unknown ids fall back to the base workshop sentry.
static func script_for(id: String) -> Script:
	if id == BOSS_ID: return BOSS
	return ENEMIES.get(id,ENEMIES.workshop_sentry)
