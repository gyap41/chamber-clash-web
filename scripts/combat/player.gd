extends Node2D
const BuildGrid = preload("res://scripts/game/build_grid.gd")
const Items = preload("res://scripts/game/item_identity.gd")
signal weapon_event_requested(event: Dictionary)
var combat_service: WeakRef
var reload_visual_token := 0
var reload_visual_active := false
var reload_visual_weapon := -1
var reload_visual_duration := 0.0
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
var equipment_offset := Vector2.ZERO
@export var reload_duration: float = 1.15
@export var dodge_duration: float = 0.26
@export var dodge_cooldown: float = 1.65
@export_range(0.0, 0.2) var input_buffer_duration: float = 0.1
var buffered_fire := 0.0
var buffered_switch := 0.0
var buffered_slot := -1
var keyboard_fire_held := false
# Legacy roll()/damage() keep invincibility (p.inv) separate from the roll animation timer
# Default characters roll for .26s; Rina dives for .38s with a vulnerable landing.
# p.inv is independently set to .31s, which gates Rina's incoming damage.
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
var participant_id := ""
var team_id := ""
var battle_roster
var battle_slot := -1
# Applies a character's base stats (HP, speed, reload multiplier, dodge cooldown, pulse
# count, portrait frame). Mutates the live state dict in place rather than calling reset(),
# so it is safe to call after reset() has already run this round (e.g. from a pre-match
# character-select screen) without disturbing position/inventory or the fighters[] reference
# main.gd keeps into this same dict.
func set_character(id: int) -> void:
	char_id = id
	dodge_duration = .38 if id == 0 else .26
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
	cancel_reload_visual()
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
func begin_encounter(spawn: Vector2, replenish: bool = false) -> void:
	var resources = preload("res://scripts/game/encounter_resources.gd")
	var snapshot: Dictionary = resources.capture(self)
	reset(spawn)
	resources.restore(self,snapshot)
	if replenish:
		state.hp = state.max_hp
		state.pulses = initial_pulses
		for i in range(inventory.size()): inventory[i] = new_weapon_entry(inventory[i].id)
	update_weapon_art()
func move_to_room(spawn: Vector2) -> void:
	# Merely changing rooms does not begin a battle or replenish resources.
	clear_action_inputs()
	state.pos = spawn
	sync_visual()
func hurt(amount: float, volley: int = -1, hazard: bool = false, origin: Dictionary = {}) -> bool:
	if state.hp <= 0 or amount <= 0: return false
	if (char_id != 0 and state.roll > 0) or (volley >= 0 and state.blocked_volley == volley) or (state.inv > 0 and (volley < 0 or state.last_volley != volley)): return false
	amount = preload("res://scripts/combat/relic_effects.gd").incoming_damage(self,amount,volley,hazard)
	if amount <= 0: return false
	state.last_volley = volley
	var actual := minf(state.hp,amount)
	state.hp = maxf(0,state.hp-amount)
	if state.hp <= 0: cancel_reload_visual()
	preload("res://scripts/combat/relic_effects.gd").damaged(self,actual,hazard)
	if telemetry != null: telemetry.record("damage",{"player":str(name),"amount":actual,"volley":volley,"hazard":hazard,"origin":origin})
	state.inv = .22
	burst_requested.emit(state.pos,visual_color(),14)
	shake_requested.emit(4.0)
	sound_requested.emit("hit",0)
	return true
func visual_color() -> Color:
	return Color("64b5ee") if name == "P2" else Color("f39545")
# Device compatibility adapter for existing effect tests. Runtime uses commands.
func handle_key(key: int, i: int, _shots: Array, _enemy, _arena) -> bool:
	if i != 0: return false
	var command := preload("res://scripts/combat/human_input.gd").key(self,key)
	if command.switch >= 0: request_switch(command.switch)
	if command.reload: start_reload()
	return try_dodge() if command.dodge else false
func try_dodge() -> bool:
	var p = state
	if p.hp <= 0 or p.dodge > 0: return false
	p.last_volley = -1
	p.roll = dodge_duration
	p.dodge = dodge_cooldown * (relic_value(24,"dodge_ratio") if 24 in relics else 1.0)
	p.inv = maxf(p.inv,dodge_invulnerability)
	burst_requested.emit(p.pos,visual_color(),8)
	sound_requested.emit("dodge",0)
	return preload("res://scripts/combat/relic_effects.gd").dodge_started(self)
func hostile_slot(other: int, own: int) -> bool:
	return battle_roster.hostile(own,other) if battle_roster != null else own != other
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
		if hostile_slot(b.owner,i) and not b.dead and offset.length() <= melee_range and absf(wrapf(offset.angle()-p.angle,-PI,PI)) <= PI/3 and removed < melee_limit and not arena.line_blocked(p.pos,b.pos):
			b.dead = true
			burst_requested.emit(b.pos,Color(b.color),6)
			removed += 1
	preload("res://scripts/combat/relic_effects.gd").melee_cleared(self,removed)
	var targets: Array = enemy if enemy is Array else ([enemy] if enemy != null else [])
	for target in targets:
		var offset: Vector2 = target.state.pos-p.pos
		if offset.length() < melee_range and absf(wrapf(offset.angle()-p.angle,-PI,PI)) <= PI/3 and not arena.line_blocked(p.pos,target.state.pos): target.hurt(melee_damage)
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
	# Compatibility arguments adapt to the same data path; no device reads here.
	var command := ai
	if command.is_empty():
		command = preload("res://scripts/combat/combat_command.gd").idle(p.angle)
		command.shoot = mouse_shooting
	var axis := Vector2(command.dx,command.dy).normalized()
	p.angle = float(command.get("angle",(enemy.state.pos-p.pos).angle()+float(command.get("aim_jitter",0.0)) if enemy != null else p.angle))
	if char_id == 0 and previous_roll > 0:
		# Integrate the speed curve over this step, including the final partial tick.
		var start := clampf(1.0-previous_roll/dodge_duration,0,1)
		var finish := clampf(1.0-p.roll/dodge_duration,0,1)
		var distance := roll_speed*.26*((2*finish-finish*finish)-(2*start-start*start))
		arena.move_fighter(p,p.dir*distance,radius)
		var remaining := maxf(0.0,dt-previous_roll)
		if remaining > 0:
			arena.move_fighter(p,axis*effective_move_speed()*remaining,radius)
	else:
		if p.roll <= 0 and axis.length() > 0: p.dir = axis
		arena.move_fighter(p,p.dir*roll_speed*dt if p.roll > 0 else axis*effective_move_speed()*dt,radius)
	$Animation.advance(dt,axis.length() > 0)
	sync_visual()
	var shooting: bool = command.shoot or fire_pending
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
	if has_weapon() and Weapons.EQUIPMENT_POINTS.has(weapon().id):
		$Weapon/Sprite.position = equipment_offset * Vector2(1,-1 if $Weapon/Sprite.flip_v else 1)
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
	preload("res://scripts/combat/relic_effects.gd").recovered(self,id)
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
	preload("res://scripts/combat/relic_effects.gd").switching(self)
	cancel_reload_visual()
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
	reload_visual_token += 1
	reload_visual_active = true
	reload_visual_weapon = weapon().id
	reload_visual_duration = state.reload
	emit_weapon_event("reload_start",reload_visual_weapon)
	preload("res://scripts/combat/weapon_behaviors.gd").dispatch(reload_visual_weapon,&"reload_start",{"actor":self})
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
	preload("res://scripts/combat/relic_effects.gd").reload_completed(self,amount,w)
	if reload_visual_active:
		emit_weapon_event("reload_complete" if amount>0 and state.hp>0 else "reload_cancel",reload_visual_weapon)
	if amount>0: preload("res://scripts/combat/weapon_behaviors.gd").dispatch(w.id,&"reload_complete",{"actor":self,"amount":amount})
	reload_visual_active = false
	state.reload_started_empty = false
	state.reload_slot = -1
func update_weapon_art() -> void:
	$Weapon.visible = has_weapon()
	if not has_weapon(): return
	$Weapon/Sprite.texture = Weapons.art(weapon().id)
	$Weapon/Sprite.scale = weapon_display_size / $Weapon/Sprite.texture.get_size()
	if Weapons.EQUIPMENT_POINTS.has(weapon().id):
		var size: Vector2 = $Weapon/Sprite.texture.get_size()
		var ratio := minf(weapon_display_size.x/size.x,weapon_display_size.y/size.y)
		ratio *= float(Weapons.EQUIPMENT_SCALE.get(weapon().id,1.0))
		$Weapon/Sprite.scale = Vector2.ONE*ratio
		equipment_offset = Vector2(8,0)+(Vector2(.5,.5)-Weapons.EQUIPMENT_POINTS[weapon().id][0])*size*ratio
		$Weapon/Sprite.position = equipment_offset * Vector2(1,-1 if cos(float(state.get("angle",0.0)))<0 else 1)
	elif Weapons.Visuals.profile(weapon().id).get("body",{}).has("fixed_width"):
		var body: Dictionary = Weapons.Visuals.profile(weapon().id).body
		$Weapon/Sprite.scale = Vector2.ONE*float(body.fixed_width)/$Weapon/Sprite.texture.get_width()
		$Weapon/Sprite.position = Weapons.Visuals.vec(body.offset)
	else:
		$Weapon/Sprite.position = Vector2(23,0)

func equipment_muzzle() -> Vector2:
	var sprite: Sprite2D = $Weapon/Sprite
	var point: Vector2 = Weapons.EQUIPMENT_POINTS[weapon().id][1]
	return sprite.position+(point-Vector2(.5,.5))*sprite.texture.get_size()*sprite.scale*Vector2(1,-1 if sprite.flip_v else 1)

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
			if hostile_slot(b.state.owner,index) and not b.state.dead and b.state.pos.distance_to(state.pos) < phase_radius:
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

func cancel_reload_visual() -> void:
	if not reload_visual_active: return
	emit_weapon_event("reload_cancel",reload_visual_weapon)
	preload("res://scripts/combat/weapon_behaviors.gd").dispatch(reload_visual_weapon,&"reload_cancel",{"actor":self})
	reload_visual_active = false

func emit_weapon_event(kind: String, id: int) -> void:
	var event := {"kind":kind,"weapon":id,"owner":participant_id,"token":reload_visual_token,"duration":reload_visual_duration,"anchor":weakref(self),"pos":position,"angle":float(state.get("angle",0.0))}
	$Animation.weapon_event(event)
	weapon_event_requested.emit(event)

func presentation_muzzle(id: int, angle: float) -> Vector2:
	if has_weapon() and weapon().id == id and $Weapon/Sprite.texture != null:
		if Weapons.EQUIPMENT_POINTS.has(id): return $Weapon.to_global(equipment_muzzle())
		var offset: Vector2 = Weapons.Visuals.vec(Weapons.Visuals.profile(id).get("body",{}).get("muzzle_offset",[30,0]))
		return $Weapon.to_global(offset*Vector2(1,-1 if cos(angle)<0 else 1))
	# A delayed shot retains its source weapon even if the actor has switched away.
	return position+Vector2.from_angle(angle)*30.0
