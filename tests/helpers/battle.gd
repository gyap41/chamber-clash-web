extends RefCounted
# Combat regressions isolate weapon effects from random initial relics.
static func start(game, gun: int = 1) -> void:
	game.match_state.weapons = [[gun],[1]]
	for i in range(2):
		game.preparation.turn = i
		assert(game.preparation.select_gun(gun if i == 0 else 1))
		for id in game.match_state.rewards[i]:
			if game.match_state.remaining[i] > 0: assert(game.preparation.claim(id))
		assert(game.match_state.confirm(i))
	game.launch_round()
	assert(game.phase == "play")
	# Initial random relics can reserve holster shots during launch_round(). Removing only
	# the IDs leaves those reservations and trigger flags alive in combat-only tests.
	game.delayed_shots.clear()
	for i in range(2):
		var player = game.players[i]
		player.reset(player.state.pos)
		player.apply_build({"owned":[],"equipped":[],"main":gun if i == 0 else 1},3,true)
		game.fighters[i] = player.state
