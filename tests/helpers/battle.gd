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
	for player in game.players:
		player.relics.clear()
		player.owned_relics.clear()
		player.state.max_hp = player.max_hp
		player.state.hp = player.max_hp
