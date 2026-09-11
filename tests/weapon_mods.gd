extends SceneTree
const Weapons = preload("res://scripts/catalog/weapon_catalog.gd")
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var game = load("res://scenes/game/main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)

	# --- Catalog: which weapons are moddable, branch lookup, non-mutating resolution ---
	assert(Weapons.moddable(1) and Weapons.moddable(5) and Weapons.moddable(11) and Weapons.moddable(13))
	assert(not Weapons.moddable(0) and not Weapons.moddable(2))
	assert(Weapons.mods_for(1).size() == 2 and Weapons.mods_for(5).size() == 2 and Weapons.mods_for(11).size() == 2 and Weapons.mods_for(13).size() == 2)
	var resolved := Weapons.resolved_definition(1,"extra_bounce")
	assert(resolved.bounce == 3 and is_equal_approx(resolved.damage,0.85))
	assert(Weapons.definition(1).bounce == 2) # shared catalog entry itself is never mutated
	assert(Weapons.resolved_definition(1,"unknown_key").bounce == 2) # unknown key falls back to base
	assert(Weapons.resolved_definition(1,"").bounce == 2) # no branch active: plain base definition
	assert(Weapons.parse_mod_token("mod:1:extra_bounce") == {"weapon_id":1,"mod_key":"extra_bounce"})
	assert(Weapons.parse_mod_token("not_a_token").is_empty())
	assert(Weapons.mod_token(11,"wide_sensor") == "mod:11:wide_sensor")

	# --- MatchState: mod candidates only appear for a carried, unmodified, moddable weapon ---
	# P8z：起点が「主力」から「グリッドに置いている武器」へ変わった。所持庫に持っているだけでは
	# 対象にならず、実際に置いて携行して初めて改造が提示される。
	game.reset_round()
	var m = game.match_state
	var gun0: String = m.gun_token(0)
	var gun1: String = m.gun_token(1)
	assert(m.builds[0].owned == [gun0]) # 既定の初期武器だけを所持、まだ置いていない
	assert(m.mod_candidates(0).is_empty()) # 何も携行していない
	assert(m.place(0,gun0,Vector2i(0,0))) # サイドアーム: not moddable
	assert(m.mod_candidates(0).is_empty())
	m.builds[0].owned.append(gun1)
	assert(m.toggle(0,gun0)) # 置き場を空ける
	assert(m.place(0,gun1,Vector2i(0,0))) # 跳弾キャンディ: moddable, unmodified
	var tokens: Array = m.mod_candidates(0)
	assert(tokens.size() == 2 and Weapons.mod_token(1,"extra_bounce") in tokens and Weapons.mod_token(1,"heavy_bounce") in tokens)
	m.builds[0].mods[1] = "extra_bounce"
	assert(m.mod_candidates(0).is_empty()) # already modified: no further offers for this weapon

	# --- claim()/reason(): a mod token records into builds[i].mods, never owned/equipped,
	# and once claimed the *other* branch for the same weapon reports "改造済み" specifically
	# (not just "no reward budget left") while the branch just claimed is gone from future pools. ---
	var gun5: String = m.gun_token(5)
	m.builds[1].owned.append(gun5)
	assert(m.place(1,gun5,Vector2i(0,0))) # ムーンリーパーを携行
	m.rewards[1] = [0,1,2] + m.mod_candidates(1)
	m.remaining[1] = 1
	var token := Weapons.mod_token(5,"swift_blade")
	assert(m.reason(1,token) == "")
	assert(m.claim(1,token))
	assert(m.builds[1].mods.get(5,"") == "swift_blade")
	assert(m.builds[1].owned.filter(func(e): return typeof(e) == TYPE_INT).is_empty()) # mods never land in the 8-slot storage (武器トークンだけが入っている)
	assert(m.remaining[1] == 0)
	m.remaining[1] = 1 # isolate the "already modded" check from the separate "budget spent" one
	assert(m.reason(1,Weapons.mod_token(5,"heavy_blade")) == "改造済み")
	m.remaining[1] = 0

	# --- Taking the weapon off the grid leaves the old branch attached but inactive ("旧武器の
	# 改造は移転しない"), and a now-stale offer left in rewards[] never softlocks confirm(): the
	# reason()-based gate treats it as resolved (unclaimable) rather than still-outstanding. ---
	assert(m.toggle(1,gun5)) # グリッドから外す＝携行をやめる
	m.remaining[1] = 1 # isolate "not carried" from the "already resolved" check above (mod_reason
	# checks remaining[i]<=0 before the carried check, and remaining[] was left at 0 by that check)
	assert(m.reason(1,token) == "携行していない")
	m.rewards[1] = [token] # the only candidate left is unclaimable from here on
	assert(m.confirm(1))

	# --- A build dict without a "mods" key at all (older call sites, ad-hoc test literals)
	# must not crash reward generation or claiming. ---
	m.builds[0] = {"owned":[gun1],"equipped":[gun1],"positions":{gun1:Vector2i(0,0)}}
	assert(m.mod_candidates(0).size() == 2) # reads default via .get(), no crash
	m.rewards[0] = m.mod_candidates(0)
	m.remaining[0] = 1
	assert(m.claim(0,m.rewards[0][0])) # writes create the "mods" key on demand
	assert(m.builds[0].mods.size() == 1)

	# --- Player: apply_build() carries mods keyed by weapon id; definition() only reflects
	# the branch belonging to whichever weapon is actually equipped right now. ---
	var build := {"owned":[gun1],"equipped":[gun1],"positions":{gun1:Vector2i(0,0)},"mods":{1:"heavy_bounce",5:"swift_blade"}}
	var p = game.players[0]
	p.reset(p.state.pos)
	p.apply_build(build,3,true)
	assert(p.weapon().id == 1)
	assert(is_equal_approx(p.definition().damage,1.35) and is_equal_approx(p.definition().speed,332.0))
	p.add_gun(5) # switching the equipped weapon activates *that* weapon's own branch instead
	assert(is_equal_approx(p.definition().damage,0.8) and is_equal_approx(p.definition().speed,468.0))

	# --- Bullet: a shot fired from a modded weapon carries the branch's damage/speed/bounce,
	# while ammo bookkeeping (mag/clip) stays untouched — no branch overrides mag/stock. ---
	game.reset_round()
	preload("res://tests/helpers/battle.gd").start(game,1)
	var q = game.players[0]
	q.weapon_mods[1] = "extra_bounce"
	q.state.pos = Vector2(170,100)
	q.state.angle = 0.0
	q.state.shot = 0.0
	game.fire(0)
	var bullet = game.shots[-1]
	assert(bullet.state.bounce == 3 and is_equal_approx(bullet.damage,0.85))
	assert(q.weapon().clip == int(Weapons.definition(1).mag)-1)

	# --- Bubble activation delay flows end to end: catalog override -> resolved definition ->
	# spawned bullet's own per-instance timer (projectile.gd no longer hardcodes 1.0s). ---
	game.reset_round()
	preload("res://tests/helpers/battle.gd").start(game,13)
	var r = game.players[0]
	r.weapon_mods[13] = "early_pop"
	r.state.pos = Vector2(170,100)
	r.state.angle = 0.0
	r.state.shot = 0.0
	game.fire(0)
	var bubble = game.shots[-1]
	assert(is_equal_approx(bubble.state.bubble_delay,0.6) and is_equal_approx(bubble.damage,0.44))

	print("PASS: moddable catalog lookup, non-mutating resolution, reward offer/claim/stale-token gating, player+bullet stat application")
	game.queue_free()
	quit()
