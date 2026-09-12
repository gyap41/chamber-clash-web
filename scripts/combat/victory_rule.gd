extends RefCounted
# Elimination, then mean remaining HP ratio at timeout. A duel retains its old rule.
static func evaluate(roster, players: Array, timed_out: bool) -> Dictionary:
	var teams := {}
	var alive := {}
	for i in range(players.size()):
		var team = roster.participants[i].team
		if not teams.has(team): teams[team] = {"ratio":0.0,"count":0}
		teams[team].ratio += maxf(0,players[i].state.hp)/players[i].state.max_hp
		teams[team].count += 1
		if players[i].state.hp > 0: alive[team] = true
	if not timed_out and alive.size() > 1: return {}
	var winners: Array = []
	var best := -1.0
	for team in teams:
		var ratio: float = teams[team].ratio/teams[team].count
		best = maxf(best,ratio)
	for team in teams:
		if absf(teams[team].ratio/teams[team].count-best) < .001: winners.append(team)
	var winner = winners[0] if winners.size() == 1 and best > 0 else null
	var slots: Array = []
	var ids: Array = []
	for i in range(players.size()):
		if roster.participants[i].team == winner:
			slots.append(i)
			ids.append(roster.participants[i].id)
	return {"draw":winner == null,"team":winner,"slots":slots,"participants":ids}
