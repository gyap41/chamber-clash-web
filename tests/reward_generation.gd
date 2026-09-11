extends SceneTree
const Match = preload("res://scripts/game/match_state.gd")
func _initialize() -> void:
	var a = Match.new(445)
	var b = Match.new(445)
	assert(a.rewards == b.rewards and a.rewards[0] == a.rewards[1]) # P8z：武器候補リスト(weapons)は主力選択とともに廃止
	for n in range(10):
		a.generate_rewards()
		b.generate_rewards()
		assert(a.rewards == b.rewards)
	# P3 added relic ids 12-17 (Relics.SUPPORTED now runs 0-17, 18 total): the "one short of the
	# full pool" / "fully owned" bounds below shift from 11/12 to 17/18 accordingly.
	assert(a.generator.candidates([17,18,19],range(17)) == [17,18,19])
	assert(a.generator.candidates([18,19],range(20)) == [18,19])
	a.rewards = [[0,1,2],[0,1,2]]
	assert(a.claim(0,0) and a.claim(1,0))
	assert(not a.claim(0,0) and not a.claim(0,-1))
	a.initial = false
	a.remaining = [1,1]
	a.temporary = [8,-1]
	assert(a.claim(0,8) and not a.claim(0,1) and a.reward_counts[0] == 1)
	assert(a.claim(1,1) and a.reward_counts == [1,1])
	# P8z：主力の指定がなくなり、準備完了を塞ぐのは未取得の報酬だけになった（武器0丁でも開始できる）。
	assert(a.confirm(0) and not a.confirm(0) and not a.claim(0,2))
	assert(not a.toggle(0,0) and not a.discard(0,0))
	print("PASS: seeded/common/independent rewards, shortage, duplicate, temporary costs one reward, double confirm")
	quit()
