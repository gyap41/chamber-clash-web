extends Node2D
const BuildGrid = preload("res://scripts/game/build_grid.gd")
const Items = preload("res://scripts/game/item_identity.gd")
signal burst_requested(pos: Vector2, color: Color, count: int)
signal ring_requested(pos: Vector2, color: Color, expansion: float)
signal shake_requested(strength: float)
# Reconstructed 2026-09-08 alongside main.gd/hud.gd: mirrors the burst/ring/shake signal
# pattern above for the combat sound cues confirmed by tests/sound.gd (hit/bell/reload/
# dodge/slash). main.gd's fire()/use_pulse()/spawn_well() call sound.play_sound() directly
# since they already have the relevant weapon id / kind in scope there.
signal sound_requested(kind: String, id: int)
# P3 synergy relic (残響ホルスター) reserves a delayed follow-up shot from the *outgoing*
# weapon at the moment of a switch. Player has no back-reference to main.gd's delayed_shots/
# origin_counter, so it asks via signal instead, matching the burst/ring/shake/sound pattern
# above; main.gd owns the actual spawn timing and pulse-clearing behavior.
signal delayed_shot_requested(data: Dictionary)
@export_range(0,4) var initial_pulses: int = 2
@export var pulse_invulnerability := .65
@export var max_hp: float = 8.0
@export var move_speed: float = 205.0
@export var roll_speed: float = 590.0
@export var radius: float = 14.0
@export var weapon_display_size := Vector2(40,30)
@export var reload_duration: float = 1.15
@export var dodge_duration: float = 0.26
@export var dodge_cooldown: float = 1.65
@export_range(0.0, 0.2) var input_buffer_duration: float = 0.1
var buffered_fire := 0.0
var buffered_switch := 0.0
var buffered_slot := -1
var keyboard_fire_held := false
# Legacy roll()/damage() keep invincibility (p.inv) separate from the roll animation timer
# (p.roll=.26): p.inv=Math.max(p.inv,.31) is set independently and is what damage() actually
# gates on, so a dodge is invincible for .31s even though the roll animation itself is .26s.
# handle_key() below previously relied on state.roll alone for the dodge's invincibility
# window (via hurt()'s `state.roll > 0` check), which is .05s shorter than legacy.
@export var dodge_invulnerability: float = 0.31
@export var melee_cooldown: float = 1.1
@export var melee_range: float = 64.0
@export var melee_damage: float = 0.6
@export var melee_limit: int = 3
const Weapons = preload("res://scripts/catalog/weapon_catalog.gd")
const Relics = preload("res://scripts/catalog/relic_catalog.gd")
const Characters = preload("res://scripts/catalog/character_catalog.gd")
var inventory: Array = []
var match_inventory
var match_player_index := -1
# P5: weapon_key(int) -> mod branch key(String) for the currently applied build, mirroring
# MatchState.builds[i].mods. Keyed by weapon id (not inventory slot) so a branch stays
# attached to the weapon it was chosen for even if the player's main later changes — see
# resolved_definition()/definition() below, which are the only readers.
var weapon_mods: Dictionary = {}
var relics: Array = []
var relic_capacity := 3
var owned_relics: Array = []
var temporary_relic := -1
var temporary_relic_slot := -1
var field_region := {}
var field_occupied := {}
var telemetry
var state: Dictionary = {}
var char_id := -1
# Equipment-triggered timers are separate from persistent character stats.
const ITEM_TIMERS := ["cool_grip_cd","sole_time","shell_time","shell_cd","aid_time","boots_time","sight_time","sight_cd","reel_cd"]
# Set by character_select.gd when CPU mode is chosen (always player index 1, matching the
# legacy web version's mode==='cpu' hardcoding). Persists across reset_round() like char_id.
var is_cpu := false
# Applies a character's base stats (HP, speed, reload multiplier, dodge cooldown, pulse
# count, portrait frame). Mutates the live state dict in place rather than calling reset(),
# so it is safe to call after reset() has already run this round (e.g. from a pre-match
# character-select screen) without disturbing position/inventory or the fighters[] reference
# main.gd keeps into this same dict.
func set_character(id: int) -> void:
	char_id = id
	var c: Dictionary = Characters.definition(id)
	max_hp = c.hp
	move_speed = c.speed
	reload_duration = 1.15 * c.reload
	dodge_cooldown = c.dodge
	initial_pulses = c.blanks
	if not state.is_empty():
		state.hp = max_hp
		state.max_hp = max_hp
		state.pulses = initial_pulses
	$Sprite.frame = int(c.cell)
func reset(spawn: Vector2) -> void:
	clear_action_inputs()
	$Animation.reset()
	relics.clear()
	owned_relics.clear()
	field_region.clear()
	field_occupied.clear()
	temporary_relic = -1
	temporary_relic_slot = -1
	# ai_cd: CPU-only dodge-roll cooldown (legacy makePlayer()'s p.ai=rnd(.25,.6); unused by
	# human players). Decremented only while a bullet threat is present, see cpu_ai.gd.
	# P3 synergy state (all reset every round, same as the timers above): reload_started_empty
	# tracks whether the *current* reload attempt began from a fully empty clip (空薬莢の祝福);
	# empty_casing_charge/residual_heat_charge/return_battery_charge are one-shot "next fire()
	# gets a bonus" flags; return_battery_armed distinguishes "charged" from "switched while
	# charged, next shot is boosted"; echo_holster_cd is a plain cooldown timer (decremented
	# alongside the other timers in step()); phase_load_used resets at the start of each dodge.
	state = {"pulses":initial_pulses,"pos":spawn,"hp":max_hp,"max_hp":max_hp,"angle":0.0,"shot":0.0,"roll":0.0,"dodge":0.0,"slash":0.0,"melee":0.0,"inv":0.0,"reload":0.0,"reload_slot":-1,"last_volley":-1,"blocked_volley":-1,"shield":0.0,"holster":0.0,"dir":Vector2.RIGHT,"gun":0,"ai_cd":randf_range(.25,.6),"reload_started_empty":false,"empty_casing_charge":false,"residual_heat_charge":false,"return_battery_charge":false,"return_battery_armed":false,"echo_holster_cd":0.0,"phase_load_used":false}
	for timer in ITEM_TIMERS: state[timer] = 0.0
	state.aid_used = 0
	state.alternate_shots = 0
	# P8z：サイドアーム（武器0）の自動付与を廃止。携行武器はグリッドに置いた武器だけになったので、
	# reset()の時点では常に丸腰で、apply_build(..., heal=true)がビルドから組み直す。
	inventory = []
	update_weapon_art()
	sync_visual()
func hurt(amount: float, volley: int = -1, hazard: bool = false, origin: Dictionary = {}) -> bool:
	if state.hp <= 0 or amount <= 0: return false
	if state.roll > 0 or (volley >= 0 and state.blocked_volley == volley) or (state.inv > 0 and (volley < 0 or state.last_volley != volley)): return false
	if not hazard and 3 in relics and state.shield <= 0:
		state.blocked_volley = volley
		state.last_volley = -1
		state.shield = 12.0
		state.inv = .3
		ring_requested.emit(state.pos,Color("ffe2a0"),65.0)
		sound_requested.emit("bell",0)
		return false
	if not hazard and 27 in relics and state.shell_time > 0:
		state.shell_time = 0.0
		amount = maxf(0.0,amount-relic_value(27,"shell_reduction"))
		if amount <= 0: return false
	state.last_volley = volley
	var actual := minf(state.hp,amount)
	state.hp = maxf(0,state.hp-amount)
	if not hazard and actual > 0 and state.hp > 0 and 28 in relics and state.aid_time <= 0 and state.aid_used < int(relic_value(28,"aid_limit")):
		state.aid_used += 1
		state.aid_time = relic_value(28,"aid_delay")
	if telemetry != null: telemetry.record("damage",{"player":str(name),"amount":actual,"volley":volley,"hazard":hazard,"origin":origin})
	state.inv = .22
	burst_requested.emit(state.pos,visual_color(),14)
	shake_requested.emit(4.0)
	sound_requested.emit("hit",0)
	return true
func visual_color() -> Color:
	return Color("64b5ee") if name == "P2" else Color("f39545")
func handle_key(key: int, i: int, shots: Array, enemy, arena) -> bool:
	var p = state
	var dodge_nova := false
	if key == [KEY_E,KEY_K][i] and not inventory.is_empty(): request_switch((int(p.gun)+1) % inventory.size())
	# P8z：携行数がグリッド由来で最大8丁になりうるため、直接指定も1〜8へ広げた（P1限定）。
	if i == 0 and key >= KEY_1 and key <= KEY_8: request_switch(key-KEY_1)
	if key == [KEY_R,KEY_P][i]: start_reload()
	if key == [KEY_SPACE,KEY_SHIFT][i] and p.dodge <= 0:
		p.last_volley = -1
		p.roll = dodge_duration
		p.dodge = dodge_cooldown * (relic_value(24,"dodge_ratio") if 24 in relics else 1.0)
		p.inv = maxf(p.inv,dodge_invulnerability)
		p.phase_load_used = false # すり抜け装填: fresh one-per-dodge opportunity
		burst_requested.emit(p.pos,visual_color(),8)
		sound_requested.emit("dodge",0)
		if 5 in relics: dodge_nova = true
	# P1's melee moved to a mouse right-click (see main.gd's _unhandled_input → try_melee()) as
	# part of a fully mouse-driven control scheme (aim/shoot/melee on the mouse, movement on
	# WASD). P2's local-keyboard fallback keeps N.
	if i == 1 and key == KEY_N:
		try_melee(i,shots,enemy,arena)
	return dodge_nova
# Shared melee body, reachable either from handle_key() (P2's N key) or directly from a mouse
# click (P1's right-click, see main.gd). Cooldown/reload/roll guard is checked here so both
# callers get it for free.
func try_melee(i: int, shots: Array, enemy, arena) -> void:
	var p = state
	if p.melee > 0 or p.reload > 0 or p.roll > 0: return
	p.melee = melee_cooldown * (relic_value(26,"melee_ratio") if 26 in relics else 1.0)
	p.slash = .16
	p.shot = maxf(p.shot,.3)
	sound_requested.emit("slash",0)
	var removed := 0
	for bullet in shots:
		var b = bullet.state
		var offset: Vector2 = b.pos-p.pos
		# Legacy inSlash() (game.js:47) requires !lineBlocked(p,target) for both the bullets
		# melee eats and the enemy it can hit; a wall between the two blocks the swing.
		if b.owner != i and not b.dead and offset.length() <= melee_range and absf(wrapf(offset.angle()-p.angle,-PI,PI)) <= PI/3 and removed < melee_limit and not arena.line_blocked(p.pos,b.pos):
			b.dead = true
			burst_requested.emit(b.pos,Color(b.color),6)
			removed += 1
	if removed > 0 and 10 in relics: p.dodge = maxf(0,p.dodge-.3)
	# 余熱コンデンサ: melee that clears at least one bullet charges a bonus pellet for the next
	# shot. removed>0 can only become true once per try_melee() call, so this is naturally
	# "once per swing"; the flag itself caps the charge at one (no stacking).
	if removed > 0 and 15 in relics: p.residual_heat_charge = true
	if removed > 0 and 27 in relics and p.shell_cd <= 0:
		p.shell_time = relic_value(27,"shell_duration")
		p.shell_cd = relic_value(27,"shell_reuse")
	var offset: Vector2 = enemy.state.pos-p.pos
	if offset.length() < melee_range and absf(wrapf(offset.angle()-p.angle,-PI,PI)) <= PI/3 and not arena.line_blocked(p.pos,enemy.state.pos): enemy.hurt(melee_damage)
func step(dt: float, i: int, enemy, arena, mouse_shooting: bool = false, ai: Dictionary = {}) -> bool:
	var p = state
	var fire_pending := buffered_fire > 0.0 and dt <= buffered_fire + 0.000001
	var switch_pending := buffered_switch > 0.0 and dt <= buffered_switch + 0.000001
	buffered_fire = maxf(0.0, buffered_fire-dt)
	buffered_switch = maxf(0.0, buffered_switch-dt)
	var previous_roll: float = p.roll
	var previous_aid: float = p.aid_time
	for timer in ITEM_TIMERS: p[timer] = maxf(0.0,p[timer]-dt)
	if previous_aid > 0 and p.aid_time == 0 and p.hp > 0 and 28 in relics:
		p.hp = minf(p.max_hp,p.hp+relic_value(28,"aid_heal"))
	for timer in ["shot","roll","dodge","slash","melee","inv","shield","holster","echo_holster_cd"]: p[timer] = maxf(0,p[timer]-dt)
	if previous_roll > 0 and p.roll <= 0 and 25 in relics:
		p.sole_time = maxf(0.0,relic_value(25,"sole_duration")-(dt-previous_roll))
	if p.roll <= 0 and switch_pending:
		var slot := buffered_slot
		buffered_switch = 0.0
		buffered_slot = -1
		equip_slot(slot)
	if p.reload > 0:
		p.reload = maxf(0,p.reload-dt)
		if p.reload == 0:
			finish_reload()
	var axis: Vector2
	var jitter := 0.0
	if not ai.is_empty():
		# CPU-controlled: cpu_ai.gd already computed the (pre-normalization) move vector,
		# shoot decision, and aim jitter for this frame; no physical input is read at all.
		axis = Vector2(ai.dx,ai.dy).normalized()
		jitter = ai.aim_jitter
		p.angle = (enemy.state.pos-p.pos).angle() + jitter
	else:
		var keys: Array = [KEY_A,KEY_D,KEY_W,KEY_S] if i == 0 else [KEY_LEFT,KEY_RIGHT,KEY_UP,KEY_DOWN]
		axis = Vector2(float(Input.is_physical_key_pressed(keys[1]))-float(Input.is_physical_key_pressed(keys[0])),float(Input.is_physical_key_pressed(keys[3]))-float(Input.is_physical_key_pressed(keys[2]))).normalized()
		# P1 (human) aims freely at the mouse cursor rather than auto-locking onto the enemy —
		# a deliberate departure from legacy (and from the CPU/P2 paths above and below), per
		# the mouse-driven control scheme. P2's local-keyboard fallback keeps the legacy
		# auto-lock-onto-enemy behavior, since it has no mouse of its own in this scheme.
		p.angle = (get_global_mouse_position()-p.pos).angle() if i == 0 else (enemy.state.pos-p.pos).angle()
	if p.roll <= 0 and axis.length() > 0: p.dir = axis
	arena.move_fighter(p,p.dir*roll_speed*dt if p.roll > 0 else axis*effective_move_speed()*dt,radius)
	$Animation.advance(dt,axis.length() > 0)
	sync_visual()
	var shooting: bool = ai.shoot if not ai.is_empty() else ((mouse_shooting if i == 0 else keyboard_fire_held) or fire_pending)
	if shooting and has_weapon() and weapon().clip == 0: start_reload()
	var ready := shooting and can_fire()
	if ready: buffered_fire = 0.0
	return ready
func clear_action_inputs() -> void:
	buffered_fire = 0.0
	buffered_switch = 0.0
	buffered_slot = -1
	keyboard_fire_held = false
func request_fire() -> void:
	if state.roll > 0.0 and state.roll <= input_buffer_duration:
		buffered_fire = input_buffer_duration
func request_switch(index: int) -> void:
	if index < 0 or index >= inventory.size(): return
	if state.roll > 0.0:
		if state.roll <= input_buffer_duration:
			buffered_slot = index
			buffered_switch = input_buffer_duration
		return
	equip_slot(index)
func can_fire() -> bool:
	return has_weapon() and state.shot <= 0 and state.reload <= 0 and state.roll <= 0 and weapon().clip > 0
func consume_shot() -> void:
	if not has_weapon(): return
	weapon().clip -= 1
	state.alternate_shots += 1
	state.shot = definition().rate
	$Animation.fire()
func sync_visual() -> void:
	position = state.pos
	$Aim.rotation = state.angle
	$Identity.text = str(name) + (" [仮]" if temporary_relic >= 0 else "")
	$Identity.tooltip_text = Relics.definition(temporary_relic).desc if temporary_relic >= 0 else ""
	$Weapon.rotation = state.angle
	$Weapon/Sprite.flip_v = cos(state.angle) < 0
	$Slash.visible = state.slash > 0
	$Slash.rotation = state.angle
	$Animation.refresh()

# P8z ステップA 丸腰耐性：ステップBで武器をグリッドに置く方式へ移ると、1丁も置かなかった
# プレイヤーはinventoryが空のままラウンドを迎えうる。weapon()はinventory[state.gun]を無条件に
# 添字参照していたため、毎フレーム走るstep()やHUDを含む約20箇所がその状態で落ちる。ここで
# 「武器を持っていない」を正式な状態として扱えるようにしておく（この時点ではinventoryが空に
# なる経路がまだ無いので、振る舞いは一切変わらない）。近接・回避・パルスは元から武器の状態を
# 参照していないため、丸腰でも戦うこと自体はできる。
const NO_WEAPON := {"id": -1, "clip": 0, "reserve": 0, "mode": 0}
# 丸腰時のdefinition()。Weapons.definition(-1)はGDScriptの負数添字で配列末尾の武器を返して
# しまうため、明示的な擬似定義を返す。can_fire()が偽になるので射撃系の値は読まれないが、
# HUDの表示（name/desc）と装填ガード（mag）は実際に参照される。
const NO_WEAPON_DEF := {"name": "素手", "desc": "武器を装備していない。近接で戦う。", "rarity": "C", "color": "#8f9aa3", "mag": 0, "stock": 0, "rate": .5, "damage": 0.0, "speed": 0.0}
func has_weapon() -> bool:
	return state.gun >= 0 and state.gun < inventory.size()
func weapon() -> Dictionary:
	# 呼び出し側にはweapon().clip -= 1 のように戻り値を直接書き換えるものがあるため、丸腰時は
	# 毎回複製を返して書き込みを無害な空振りにする（共有した定数を汚さないため）。
	return inventory[state.gun] if has_weapon() else NO_WEAPON.duplicate()
# P5: the definition for a given weapon id, with this player's active mod branch for that id
# (if any) applied. Prefer this over Weapons.definition() wherever a live weapon instance
# belonging to this player is in play, so damage/speed/bounce/etc. reflect the chosen branch.
func resolved_definition(id: int) -> Dictionary:
	var resolved := Weapons.resolved_definition(id, weapon_mods.get(id, ""))
	if 21 in relics:
		resolved = resolved.duplicate()
		resolved.mag = int(resolved.mag)+int(relic_value(21,"mag_bonus"))
	return resolved
func new_weapon_entry(id: int) -> Dictionary:
	var entry := Weapons.new_inventory_entry(id)
	entry.clip = int(resolved_definition(id).mag)
	return entry
func top_up_weapon(id: int) -> bool:
	for entry in inventory:
		if entry.id == id and entry.reserve > 0 and entry.clip < int(resolved_definition(id).mag):
			entry.clip += 1
			entry.reserve -= 1
			return true
	return false
func recover_projectile(id: int) -> void:
	if 14 in relics: state.return_battery_charge = true
	if 33 in relics and state.reel_cd <= 0 and top_up_weapon(id):
		state.reel_cd = relic_value(33,"reel_reuse")
func definition() -> Dictionary:
	return resolved_definition(weapon().id) if has_weapon() else NO_WEAPON_DEF
func owns(id: int) -> bool:
	return inventory.any(func(w): return w.id == id)
# 携行武器は操作/HUDの上限8丁を維持する。控え容量8個とは独立している。実際の上限は
# グリッドの面積とそこに置いた武器の形状で決まるので、ここは暴走防止の天井にすぎない
# （HUDの武器スロットもMAX_WEAPON_SLOTS＝8で確保している）。
const MAX_CARRIED_WEAPONS := BuildGrid.MAX_CARRIED_WEAPONS
func add_gun(id: int) -> bool:
	if not Weapons.supported(id) or owns(id) or inventory.size() >= MAX_CARRIED_WEAPONS: return false
	inventory.append(new_weapon_entry(id))
	equip_slot(inventory.size()-1)
	return true
func equip_slot(index: int) -> void:
	if index < 0 or index >= inventory.size() or index == state.gun: return
	# P8z ステップA：下の2つのレリック効果はいずれも「切り替え前の武器」を必要とするため、
	# 丸腰から1丁目を装備する場合は対象外になる（Weapons.definition(-1)が負数添字で配列末尾を
	# 返してしまうのも、ここで防いでいる）。
	if has_weapon() and 8 in relics and state.holster <= 0:
		var old := weapon()
		var old_def := resolved_definition(old.id)
		if old.reserve > 0 and old.clip < int(old_def.mag):
			old.clip += 1
			old.reserve -= 1
			state.holster = 1.5
	# 残響ホルスター: on a genuine switch (guarded by the same index==state.gun no-op check
	# above), reserve a weak follow-up shot from the *outgoing* weapon while it is still
	# `weapon()`. Consumes 1 round from the outgoing weapon's own ammo (clip first, then
	# reserve); an outgoing weapon with no ammo left simply misfires ("空なら不発") but the
	# cooldown still starts, so rapid switching cannot spam the request. main.gd turns this
	# into a delayed_shots entry (depth 1, no volley, can't re-trigger further generation) and
	# already clears the *enemy's* delayed shots on pulse via the existing owner filter, so a
	# pulse also removes any echo-holster shot the pulsing player had reserved against them.
	if has_weapon() and 16 in relics and state.echo_holster_cd <= 0:
		var outgoing := weapon()
		var outgoing_def: Dictionary = resolved_definition(outgoing.id)
		var relic16 := Relics.definition(16)
		state.echo_holster_cd = float(relic16.get("holster_cooldown",2.5))
		if int(outgoing.clip)+int(outgoing.reserve) > 0:
			if outgoing.clip > 0: outgoing.clip -= 1
			else: outgoing.reserve -= 1
			delayed_shot_requested.emit({"gun":outgoing.id,"angle":state.angle,"delay":.22,"damage":float(outgoing_def.damage)*float(relic16.get("holster_ratio",.5)),"kind":"echo_holster","can_lens":false,"depth":1})
	# 帰還バッテリー: a stored charge arms on the switch itself; the bonus is spent by the
	# *next* fire() call (see main.gd), not by this switch.
	if 14 in relics and state.return_battery_charge:
		state.return_battery_charge = false
		state.return_battery_armed = true
	if has_weapon() and 30 in relics and state.sight_cd <= 0:
		state.sight_time = relic_value(30,"sight_duration")
		state.sight_cd = relic_value(30,"sight_reuse")
	state.gun = index
	state.reload = 0.0
	state.reload_slot = -1
	state.shot = maxf(state.shot, .15)
	update_weapon_art()
	sound_requested.emit("equip",0)
func start_reload() -> void:
	if not has_weapon() or state.reload > 0 or weapon().clip >= definition().mag or weapon().reserve <= 0: return
	state.reload = effective_reload_duration()
	# P8z ステップA：装填中の武器をインベントリの添字ではなく武器idで覚える。ステップBで携行
	# 武器の並びがグリッド由来になると添字が動きうるため（idはadd_gun()が重複を弾くので一意）。
	state.reload_slot = weapon().id
	# 空薬莢の祝福 only cares about a reload that began from a *fully* empty clip; partial
	# top-ups never reach here anyway (guarded above), but this keeps the "empty" distinction
	# explicit and independent of that guard's exact bounds.
	state.reload_started_empty = weapon().clip == 0
	sound_requested.emit("reload",0)
func finish_reload() -> void:
	if not has_weapon() or state.reload_slot != weapon().id: return
	var w := weapon()
	var amount := mini(int(definition().mag)-int(w.clip), int(w.reserve))
	w.clip += amount
	w.reserve -= amount
	if amount > 0 and 23 in relics and state.cool_grip_cd <= 0:
		state.dodge = maxf(0.0,state.dodge-relic_value(23,"cool_reduction"))
		state.cool_grip_cd = relic_value(23,"cool_reuse")
	if amount > 0 and definition().get("switcher", false): w.mode = 1-w.mode
	# 空薬莢の祝福: only a reload that both started from empty AND actually completed here
	# (not interrupted — an interrupted reload never reaches finish_reload(), see the
	# reload_slot guard above, and 予備マガジン's 1-round top-up never goes through
	# start_reload()/finish_reload() at all) charges the next full-magazine shot.
	if state.reload_started_empty and 13 in relics: state.empty_casing_charge = true
	state.reload_started_empty = false
	state.reload_slot = -1
func update_weapon_art() -> void:
	$Weapon.visible = has_weapon()
	if not has_weapon(): return
	$Weapon/Sprite.texture = Weapons.art(weapon().id)
	$Weapon/Sprite.scale = weapon_display_size / $Weapon/Sprite.texture.get_size()

# No field pickup may change active ammunition, reload, weapon mode or slot.
func field_weapon_reason(id: int) -> String:
	if match_inventory == null: return "試合データなし"
	if owns(id): return "所持済み（弾薬補給は弾薬箱）"
	return match_inventory.field_weapon_reason(match_player_index,id)
func acquire_weapon(id: int, _replace: bool = false) -> String:
	if state.hp <= 0 or not field_weapon_reason(id).is_empty(): return ""
	if not match_inventory.store_field_weapon(match_player_index,id): return ""
	return Weapons.definition(id).name + "：控えへ収納・次の準備で配置"
func refill_ammo() -> int:
	var gained := 0
	for w in inventory:
		var g := Weapons.definition(w.id)
		var amount := mini(int(g.stock)-int(w.reserve),ceili(float(g.stock)*.4))
		w.reserve += amount
		gained += amount
	return gained

func relic_block_reason(id: int) -> String:
	if not Relics.supported(id): return "効果未移植・取得不可"
	if not Relics.stackable(id) and (id in relics or id in owned_relics): return "所持済み"
	if relics.size() >= relic_capacity: return "レリック%d枠が満杯" % relic_capacity
	return ""
func add_relic(id: int) -> bool:
	if relic_block_reason(id) != "": return false
	relics.append(id)
	if id == 4:
		state.max_hp += float(Relics.definition(4).hp_bonus)
		state.hp = minf(state.max_hp,state.hp+float(Relics.definition(4).hp_bonus))
	return true
func effective_move_speed() -> float:
	return move_speed*(1.0 + Relics.additive_bonus(relics,"move_bonus") + (relic_value(25,"sole_bonus") if 25 in relics and state.sole_time > 0 else 0.0) + (relic_value(29,"boots_bonus") if 29 in relics and state.boots_time > 0 else 0.0))
func effective_reload_duration() -> float:
	# reload_duration retains the Inspector/character baseline; each gun supplies its base.
	return float(definition().get("reload_time",1.15))*(reload_duration/1.15)*Relics.stacked_value(relics,1,"reload_ratio")
func relic_value(id: int, key: String) -> float:
	return Relics.stacked_value(relics,id,key)
func effective_chest_duration(base: float) -> float:
	return base*(relic_value(34,"chest_ratio") if 34 in relics else 1.0)

func field_relic_reason(id: int) -> String:
	if temporary_relic >= 0: return "仮装備は1ラウンド1個まで"
	var reason := relic_block_reason(id)
	if not reason.is_empty(): return reason
	if not field_region.is_empty():
		for anchor in field_region:
			if BuildGrid.fits(id,anchor,field_region,field_occupied): return ""
		return "バッグに仮装備の形が収まりません"
	return ""
func acquire_temporary(id: int) -> bool:
	if field_relic_reason(id) != "" or not add_relic(id): return false
	temporary_relic = id
	temporary_relic_slot = relics.size()-1
	return true
# P8z 装備モデルの統合：build.owned／build.equippedは武器とレリックの共通の置き場になった
# （新規レリックは個体トークン、旧intも対応。武器は"gun:<id>"）。ここでは
# それぞれを自分の持ち場へ振り分ける——レリックはrelics/owned_relicsへ、武器はinventoryへ。
# 「サイドアーム（武器0）の自動付与」と「主力1丁」は廃止し、グリッドに置いた武器がそのまま
# 携行武器になる。1丁も置いていなければinventoryは空＝丸腰で、近接だけで戦うことになる。
func apply_build(build: Dictionary, capacity: int, heal: bool = false, usable: Dictionary = {}) -> void:
	field_region = usable.duplicate()
	field_occupied = BuildGrid.occupied_cells(build)
	relic_capacity = capacity
	owned_relics = Items.relic_ids(build.owned)
	relics = Items.relic_ids(build.equipped)
	weapon_mods = build.get("mods", {}).duplicate()
	temporary_relic = -1
	temporary_relic_slot = -1
	state.max_hp = max_hp + relic_value(4,"hp_bonus")
	state.hp = state.max_hp if heal else minf(state.hp,state.max_hp)
	if heal:
		inventory = []
		for id in BuildGrid.carried_guns(build):
			if Weapons.supported(id) and not owns(id): inventory.append(new_weapon_entry(id))
		state.gun = 0
		state.shot = 0.0
		update_weapon_art()

# Dodge proximity loads reserve ammo without invoking reload completion effects.
func try_phase_load(shots: Array, index: int) -> void:
	if state.roll > 0 and 17 in relics and not state.get("phase_load_used",false):
		var phase_triggered := false
		var phase_radius: float = float(Relics.definition(17).get("phase_radius",42.0))
		for b in shots:
			if b.state.owner != index and not b.state.dead and b.state.pos.distance_to(state.pos) < phase_radius:
				phase_triggered = true
				break
		# P8z ステップA：すり抜け装填には装填する武器が要る。丸腰ではWeapons.definition(-1)が
		# 負数添字で配列末尾を返してしまうため、has_weapon()で手前から弾く。
		if phase_triggered and has_weapon():
			state.phase_load_used = true
			var phase_weapon: Dictionary = weapon()
			var phase_def: Dictionary = resolved_definition(phase_weapon.id)
			if phase_weapon.reserve > 0 and phase_weapon.clip < int(phase_def.mag):
				phase_weapon.clip += 1
				phase_weapon.reserve -= 1
