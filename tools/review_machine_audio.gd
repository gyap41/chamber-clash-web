extends SceneTree
func _initialize(): call_deferred("run")
func run():
 var sound=preload("res://scripts/audio/sound.gd").new()
 root.add_child(sound)
 var record:=AudioEffectRecord.new()
 AudioServer.add_bus_effect(0,record)
 record.set_recording_active(true)
 var folder="res://docs/art/production/enemy-animation-v2/"
 # 0-3 ram, 3-6 ring, 6-9 aurora, 9-15 stress with game BGM.
 for kind in ["machine_ram_launch","machine_ring_salvo","shot"]:
  sound.play_sound(kind,37 if kind=="shot" else 42)
  await create_timer(3).timeout
 root.get_node("Music").play_context("play")
 for n in range(12):
  for id in range(6):
   sound.play_sound("machine_ram_launch" if id%2==0 else "machine_ring_salvo",id+100)
  sound.play_sound("shot",37)
  await create_timer(.5).timeout
 await create_timer(1).timeout
 record.set_recording_active(false)
 var wav=record.get_recording()
 assert(wav!=null and not wav.data.is_empty())
 wav.save_to_wav(folder+"machine-aurora-divine-mix.wav")
 AudioServer.remove_bus_effect(0,AudioServer.get_bus_effect_count(0)-1)
 sound.stop_all()
 sound.queue_free()
 await process_frame
 print("PASS: master recording saved, single cues then six machines with aurora and BGM")
 quit()
