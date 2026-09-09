extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var game = load("res://scenes/game/main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	var p = game.players[0]

	# Before any character is chosen, char_id is unset and the shared Inspector defaults
	# apply (this is what every other existing test still exercises implicitly).
	assert(p.char_id == -1 and p.max_hp == 8.0 and p.move_speed == 205.0)

	# Bolt (id 3): HP10, speed190, reload x1.0, dodge cooldown 2.0, 2 pulses, sprite cell 3.
	p.set_character(3)
	assert(p.char_id == 3 and p.max_hp == 10.0 and p.move_speed == 190.0)
	assert(is_equal_approx(p.reload_duration,1.15) and is_equal_approx(p.dodge_cooldown,2.0))
	assert(p.initial_pulses == 2 and p.get_node("Sprite").frame == 3)
	# set_character() mutates the live state dict in place rather than replacing it, so it
	# is safe to call after reset() without breaking main.gd's fighters[] reference, and it
	# does not touch position or inventory.
	var old_pos: Vector2 = p.state.pos
	assert(p.state.hp == 10.0 and p.state.max_hp == 10.0 and p.state.pulses == 2)
	assert(p.state.pos == old_pos and p.inventory.size() == 1 and p.inventory[0].id == 0)

	# The dodge cooldown actually reaches state.dodge when a dodge is pressed.
	p.state.dodge = 0.0
	p.handle_key(KEY_SPACE,0,game.shots,game.players[1],game.arena)
	assert(is_equal_approx(p.state.dodge,2.0))

	# Rina (id 0): reload x1.1 and 3 pulses differ from the shared Inspector defaults even
	# though HP/speed/dodge happen to already match them, so this exercises those two fields.
	p.set_character(0)
	assert(is_equal_approx(p.reload_duration,1.15*1.1) and p.initial_pulses == 3)
	assert(p.max_hp == 8.0 and p.move_speed == 205.0 and is_equal_approx(p.dodge_cooldown,1.65))
	assert(p.get_node("Sprite").frame == 0)

	# A character persists across round resets (matches the legacy web version, where
	# selection happens once per session, not once per round).
	p.reset(Vector2(500,500))
	assert(p.state.max_hp == 8.0 and p.state.pulses == 3 and p.char_id == 0)

	# character_catalog.gd exposes all 8 roster entries.
	assert(game.players[0].Characters.count() == 8)
	assert(game.players[0].Characters.definition(7).name == "クロウ")

	# art() crops fighters.png (4 columns x 2 rows) by cell index. Checked via ratios of the
	# shared atlas size rather than hardcoded pixel values, since it's the grid math (not the
	# source image's exact dimensions) that this is meant to catch regressions in.
	var Characters = game.players[0].Characters
	var tex0: AtlasTexture = Characters.art(0) # cell 0 -> row 0, col 0 (top-left)
	var full: Vector2 = tex0.atlas.get_size()
	assert(is_equal_approx(tex0.region.size.x,full.x/4.0) and is_equal_approx(tex0.region.size.y,full.y/2.0))
	assert(tex0.region.position == Vector2.ZERO)
	assert(Characters.art(0) == tex0) # cached, not rebuilt per call
	var tex3: AtlasTexture = Characters.art(3) # Bolt, cell 3 -> row 0, col 3 (top-right)
	assert(tex3.atlas == tex0.atlas)
	assert(is_equal_approx(tex3.region.position.x,full.x/4.0*3.0) and is_equal_approx(tex3.region.position.y,0.0))
	var tex7: AtlasTexture = Characters.art(7) # Crow, cell 7 -> row 1, col 3 (bottom-right)
	assert(is_equal_approx(tex7.region.position.x,full.x/4.0*3.0) and is_equal_approx(tex7.region.position.y,full.y/2.0))

	print("PASS: character stat application (HP/speed/reload/dodge cooldown/pulses/sprite frame), live-state patch safety, persistence across reset(), portrait art() grid cropping")
	game.queue_free()
	quit()
