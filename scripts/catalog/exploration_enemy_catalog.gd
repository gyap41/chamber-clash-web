extends RefCounted
# Independent of duel character builds and shopping AI. Art is a code-drawn placeholder.
const SENTRY := {"id":"workshop_sentry","name":"工房番機","death_sound":"sentry_down","hp":2.4,"speed":95.0,
	"radius":14.0,"range":62.0,"damage":0.8,"windup":0.65,"recovery":1.1,"entry_grace":1.0}

const LIZARD := {"id":"fire_pouch_lizard","name":"火袋トカゲ","death_sound":"lizard_down","hp":1.8,"speed":80.0,
	"radius":14.0,"range":310.0,"damage":0.55,"windup":0.8,"recovery":1.4,"entry_grace":1.2,
	"shot_interval":0.22,"projectile_speed":210.0,"projectile_life":2.8}
# Negative id is outside the player weapon catalog; no shop weapon behavior is inherited.
const FIRE_SEED_ID := -1
const FIRE_SEED := {"speed":210.0,"damage":0.55,"color":"#ff9a43"}
