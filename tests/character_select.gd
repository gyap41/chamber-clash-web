extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var select = load("res://scenes/ui/character_select.tscn").instantiate()
	root.add_child(select)
	assert(select.char_turn == 0 and select.picked == [-1,-1])
	var cards: Array = select.get_node("Panel/Content/Cards").get_children()
	assert(cards.size() == 8)
	# Regression check for the reported "no portrait / cards run off screen" issue: every card
	# has a portrait icon, and clip_text+ellipsis (not an unbounded custom_minimum_size) is what
	# keeps a long note from widening the button past its fixed size. 4 columns at this fixed
	# width comfortably fit the 1120px-wide screen (245*4 + 3*8px separation = 1004px).
	for card in cards:
		assert(card.icon is AtlasTexture)
		assert(card.clip_text == true)
		assert(card.custom_minimum_size == Vector2(245,150))

	# P1 picks Bolt (id 3); main.tscn is not created until both players have picked.
	select.select_character(3)
	assert(select.char_turn == 1 and select.picked == [3,-1])
	assert(root.get_child_count() == 1) # still just the select screen

	# P2 picks Rina (id 0): the select screen hands off to main.tscn and removes itself.
	select.select_character(0)
	assert(root.get_child_count() == 1)
	var game = root.get_child(0)
	assert(game != select)
	assert(is_equal_approx(game.players[0].max_hp,10.0) and is_equal_approx(game.players[0].move_speed,190.0) and game.players[0].char_id == 3)
	assert(is_equal_approx(game.players[1].reload_duration,1.15*1.1) and game.players[1].initial_pulses == 3 and game.players[1].char_id == 0)
	# set_character() ran after main.gd's own _ready()/reset_round(), so the applied stats
	# reached the live state dict main.gd's fighters[] already points to, not a stale copy.
	assert(game.fighters[0].max_hp == 10.0 and game.fighters[1].pulses == 3)

	print("PASS: character select shows all 8 cards, P1/P2 turn order, launches main.tscn with the chosen characters applied to the live state")

	# CPU対戦: mode buttons default to local (Local pressed, Cpu not); switching to CPU mode
	# skips the P2 card screen entirely and picks P2's character at random, excluding P1's.
	var select2 = load("res://scenes/ui/character_select.tscn").instantiate()
	root.add_child(select2)
	assert(select2.get_node("Panel/Content/ModeRow/Local").button_pressed == true)
	assert(select2.get_node("Panel/Content/ModeRow/Cpu").button_pressed == false)
	select2.set_mode(true)
	assert(select2.cpu_mode == true)
	select2.select_character(0) # P1 picks リナ; CPU (P2) must not also be リナ
	assert(root.get_child_count() == 2) # select screen already handed off to a new main.tscn
	var cpu_game = null
	for child in root.get_children():
		if child != game and child != select2: cpu_game = child
	assert(cpu_game != null)
	assert(cpu_game.players[0].char_id == 0 and cpu_game.players[0].is_cpu == false)
	assert(cpu_game.players[1].char_id != 0 and cpu_game.players[1].is_cpu == true)

	# CPU対戦 also auto-completes P2's weapon draft and shop turn the instant P1 finishes
	# theirs — P2/CPU never gets an actual turn in either screen (legacy's selectGun()/
	# readyShop() mode==='cpu' branches). Drive P1 through both to confirm this end-to-end.
	cpu_game.set_physics_process(false)
	assert(cpu_game.phase == "prepare" and cpu_game.players[1].inventory.size() == 1)
	cpu_game.preparation.select_gun(cpu_game.preparation.choices[0])
	for id in cpu_game.match_state.rewards[0].slice(0,2): assert(cpu_game.preparation.claim(id))
	cpu_game.preparation.ready_shop()
	assert(cpu_game.phase == "play")
	assert(cpu_game.players[1].relics.size() == 2)
	assert(cpu_game.preparation.shop_ready == [true,true])

	# A CPU-controlled player moves under cpu_ai.gd's decision, not physical key input: step()
	# with a non-empty ai dict ignores Input entirely (see player.gd), so this is deterministic
	# in a headless test with no real keyboard/mouse state.
	var before: Vector2 = cpu_game.players[1].state.pos # spawns 780px east of P1, so it kites in
	cpu_game._physics_process(1.0/60.0)
	assert(cpu_game.players[1].state.pos != before) # moved under AI control, no input pressed

	print("PASS: CPU mode skips P2's card/draft/shop turns entirely, auto-picks a character/weapon/purchase for P2, sets is_cpu, and the resulting match drives P2 by AI on physics tick")
	game.queue_free()
	cpu_game.queue_free()
	quit()
