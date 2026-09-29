extends SceneTree
const Chest = preload("res://scripts/world/exploration_chest.gd")
const Weapons = preload("res://scripts/catalog/weapon_catalog.gd")
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	root.size = Vector2i(800,800)
	root.content_scale_size = root.size
	var sound = load("res://scripts/audio/sound.gd").new()
	root.add_child(sound)
	sound.enabled = true
	var previous := 0.0
	for rank in range(4):
		var chest = Chest.new()
		var rarity: String = ["C","B","A","S"][rank]
		var id: int = Weapons.SUPPORTED.filter(func(item): return Weapons.definition(item).rarity == rarity)[0]
		chest.reward = {"kind":"weapon","item":id,"state":"closed","source":"first_clear"}
		chest.position = Vector2(100+rank*200,180)
		root.add_child(chest)
		var opened = Chest.new()
		opened.reward = chest.reward.duplicate(true)
		opened.reward.state = "empty"
		opened.position = chest.position+Vector2(0,120)
		root.add_child(opened)
		assert(chest.CHEST_TEXTURES[rank].get_width() == 1254)
		assert(chest.CHEST_REGIONS[rank].size() == 4)
		for stage in range(4):
			var moving = Chest.new()
			moving.reward = chest.reward.duplicate(true)
			moving.reward.state = "open"
			moving.opening = moving.OPEN_DURATION
			moving.step([.0,.15,.28,.45][stage])
			assert(moving.opening_frame() == stage)
			moving.position = Vector2(100+rank*200,450+stage*90)
			root.add_child(moving)
			moving.step(0)
			assert(moving.opening_frame() == stage)
		var landing_test = Chest.new()
		landing_test.reward = chest.reward
		landing_test.spawning = .4
		landing_test.step(.4)
		assert(landing_test.landing == .3)
		landing_test.step(.3)
		assert(landing_test.landing == 0)
		landing_test.free()
		assert(chest.rarity_rank() == rank and chest.body_scale() > previous)
		previous = chest.body_scale()
		var label := Label.new()
		label.text = rarity+" / ×"+str(chest.body_scale())
		label.position = chest.position+Vector2(-35,40)
		root.add_child(label)
		var voice_index: int = sound.next_voice
		sound.play_chest_open(rank)
		var voice = sound.voices[voice_index]
		assert(voice.stream == sound.GENERATED.chest_open)
		assert(is_equal_approx(voice.pitch_scale,[1.08,1.0,.9,.8][rank]))
		assert(sound.next_voice == (voice_index+(2 if rank >= 2 else 1))%sound.voices.size())
		if rank >= 2:
			assert(sound.voices[(voice_index+1)%sound.voices.size()].stream == sound.GENERATED["legendary" if rank == 3 else "rare_pickup"])
	# A reused voice must not retain the low chest pitch.
	sound.next_voice = 0
	sound.play_sound("pickup")
	assert(sound.voices[0].pitch_scale == 1.0)
	sound.enabled = false
	var silent_index: int = sound.next_voice
	sound.play_chest_open(3)
	assert(sound.next_voice == silent_index)
	await process_frame
	await process_frame
	if "--capture" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.local/chest-rarity.png")
	print("PASS: rarity sizes, catalog mapping, opening audio layers/pitch, voice reuse and mute")
	quit()
