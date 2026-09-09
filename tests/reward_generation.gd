extends SceneTree
const Match = preload("res://scripts/game/match_state.gd")
func _initialize() -> void:
	var a = Match.new(445)
	var b = Match.new(445)
	assert(a.weapons == b.weapons and a.rewards == b.rewards and a.rewards[0] == a.rewards[1])
	for n in range(10):
		a.generate_rewards()
		b.generate_rewards()
		assert(a.rewards == b.rewards)
	assert(a.generator.candidates([0,1,2],range(11)) == [11])
	assert(a.generator.candidates([0,1,2],range(12)).is_empty())
	a.rewards = [[0,1,2],[0,1,2]]
	assert(a.claim(0,0) and a.claim(1,0))
	assert(not a.claim(0,0) and not a.claim(0,-1))
	a.initial = false
	a.remaining = [1,1]
	a.temporary = [8,-1]
	assert(a.claim(0,8) and not a.claim(0,1) and a.reward_counts[0] == 1)
	assert(a.claim(1,1) and a.reward_counts == [1,1])
	a.set_main(0,a.weapons[0][0])
	assert(a.confirm(0) and not a.confirm(0) and not a.claim(0,2))
	assert(not a.toggle(0,0) and not a.discard(0,0))
	print("PASS: seeded/common/independent rewards, shortage, duplicate, temporary costs one reward, double confirm")
	quit()
