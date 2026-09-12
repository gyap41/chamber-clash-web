extends RefCounted
# Combat regressions isolate weapon effects from random initial relics.
# P8z 装備モデルの統合：主力の選択（select_gun/set_main）が廃止され、携行武器は「グリッドに
# 置いた武器」で決まるようになった。戦闘テストはグリッドの詰め方そのものを検証したいわけでは
# ないので、ここではbuildの辞書を直接組み立てて武器2丁だけを持たせる——並びは従来の
# 「サイドアーム(0)＋指定の1丁」と同じで、inventory[0]がサイドアーム、inventory[1]が指定武器に
# なる（apply_build()はpositionsの読み順で並べるため、(0,0)と(1,0)に置いた順になる）。
# レリックは持たせない（初期レリックの乱数を武器の効果から切り離すため、従来どおり）。
static func start(game, gun: int = 1) -> void:
	var ms = game.match_state
	for i in range(2):
		game.preparation.turn = i
		if not ms.ready[i]: assert(ms.confirm(i))
	game.launch_round()
	assert(game.phase == "play")
	# Initial random relics can reserve holster shots during launch_round(). Removing only
	# the IDs leaves those reservations and trigger flags alive in combat-only tests.
	game.delayed_shots.clear()
	for i in range(2):
		var player = game.players[i]
		var id: int = gun if i == 0 else 1
		var sidearm: String = ms.gun_token(0)
		var carried: String = ms.gun_token(id)
		var build := {"owned":[sidearm],"equipped":[sidearm],"positions":{sidearm:Vector2i(0,0)},"mods":{}}
		if id != 0:
			build.owned.append(carried)
			build.equipped.append(carried)
			build.positions[carried] = Vector2i(1,0)
		player.reset(player.state.pos)
		player.apply_build(build,3,true)
		# 旧実装は「サイドアーム＋主力」を組んだあと主力を構えた状態でラウンドを始めていた
		# （add_gun()が最後にequip_slot()を呼ぶため）。既存の戦闘テストはその前提——inventory[0]が
		# 武器0で、構えているのは指定した武器——で書かれているので、ここでも最後の1丁を構えさせる。
		player.state.gun = maxi(0,player.inventory.size()-1)
		player.update_weapon_art()
		game.fighters[i] = player.state

# Isolated weapon/economy tests opt out of autonomous opponents. CPU tests enable them explicitly.
static func passive_opponents(game) -> void:
	for player in game.players: player.is_cpu = false
