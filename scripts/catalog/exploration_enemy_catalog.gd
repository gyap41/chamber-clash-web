extends RefCounted
# Independent of duel character builds and shopping AI. Art is a code-drawn placeholder.
const SENTRY := {"id":"workshop_sentry","name":"工房番機","death_sound":"sentry_down","hp":2.8,"speed":115.0,
	"radius":20.0,"range":62.0,"damage":1.2,"windup":0.65,"recovery":0.85,"entry_grace":1.0}

const LIZARD := {"id":"fire_pouch_lizard","name":"火袋トカゲ","death_sound":"lizard_down","hp":2.1,"speed":88.0,
	"radius":18.0,"range":310.0,"damage":0.9,"windup":0.8,"recovery":1.05,"entry_grace":1.2,
	"shot_interval":0.22,"projectile_speed":210.0,"projectile_life":2.8}
# Negative id is outside the player weapon catalog; no shop weapon behavior is inherited.
const FIRE_SEED_ID := -1
const FIRE_SEED := {"speed":210.0,"damage":0.9,"color":"#ff9a43"}

const QUILLBACK := {"id":"quillback","name":"棘背ヤマアラシ","death_sound":"quill_down","hp":2.4,"speed":72.0,
	"radius":20.0,"range":430.0,"damage":0.8,"windup":0.95,"recovery":1.7,"entry_grace":1.3,
	"shot_interval":0.25,"projectile_speed":250.0,"projectile_life":2.2,"shots":1,"windup_sound":"quill_windup"}
const QUILL_ID := -2
const QUILL := {"speed":250.0,"damage":0.8,"color":"#ffe4ac"}
