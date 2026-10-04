extends "res://tests/fire_pouch_lizard.gd"
func run() -> void:
 var game=load("res://scenes/game/combat_lab.tscn").instantiate()
 root.add_child(game)
 game.set_physics_process(false)
 assert(game.launch_test("courtyard",["ash_ram","triple_ring"],37))
 assert(game.arena.configure_field(field(),1).is_empty())
 var events=[]
 var ram=game.players[1]
 var ring=game.players[2]
 for actor in [ram,ring]: actor.sound_requested.connect(func(k,id): events.append([k,id]))
 reset_pair(game,ram)
 ram.attack_time=0
 ram.step(0,1,game.players[0],game.arena)
 assert(events.has(["machine_ram_windup",ram.get_instance_id()]))
 ram.spit(1,game.arena)
 assert(events.has(["machine_ram_launch",ram.get_instance_id()]))
 ram.recover()
 assert(events.has(["machine_stop",ram.get_instance_id()]) and events.has(["machine_vent",ram.get_instance_id()]))
 reset_pair(game,ring)
 ring.attack_angle=0
 ring.shots_left=3
 for n in range(3): ring.spit(2,game.arena)
 assert(events.filter(func(e): return e[0]=="machine_ring_salvo").size()==3)
 assert(ring.firing_muzzles.size()==11 and game.shots.size()==33)
 ring.state.inv=0
 ring.hurt(100)
 assert(events.has(["machine_stop",ring.get_instance_id()]))
 assert(not events.any(func(e): return e[0]=="sentry_swing"))
 var sound=game.sound
 sound.contact_times.clear()
 sound.play_sound("machine_ring_salvo",42)
 var voice=sound.voices[(sound.next_voice+14)%16]
 assert(voice.stream==sound.GENERATED.machine_ring_salvo and voice.volume_db==2)
 sound.pause_boss_audio(true)
 assert(voice.stream_paused)
 sound.pause_boss_audio(false)
 assert(not voice.stream_paused)
 sound.play_sound("machine_stop",43)
 assert(voice.playing)
 sound.play_sound("machine_stop",42)
 assert(not voice.playing)
 sound.set_enabled(false)
 var before=sound.next_voice
 sound.play_sound("machine_ram_launch",42)
 assert(sound.next_voice==before)
 var stream=sound.synthesize(sound.profile("shot",37))
 assert(stream.data.decode_s16(0)==0 and stream.data.decode_s16(stream.data.size()-2)==0)
 var visual=preload("res://scripts/visuals/combat_visuals.gd").new()
 root.add_child(visual)
 visual.weapon_event({"kind":"fire","weapon":37,"pos":Vector2.ZERO,"angle":0.0})
 assert(visual.particles.size()==14)
 for particle in visual.particles: assert(particle.velocity.x>0)
 visual.step(.5)
 assert(visual.particles.is_empty())
 visual.clear()
 assert(visual.named_effects.is_empty())
 visual.queue_free()
 game.queue_free()
 await process_frame
 print("PASS: dedicated machine cues, per-owner stop/pause/mute, three salvos, aurora soft edges and directional bounded particles")
 quit()
