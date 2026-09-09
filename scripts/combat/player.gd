extends Node2D
signal burst_requested(pos: Vector2, color: Color, count: int)
signal ring_requested(pos: Vector2, color: Color, expansion: float)
signal shake_requested(strength: float)
# Reconstructed 2026-09-08 alongside main.gd/hud.gd: mirrors the burst/ring/shake signal
# pattern above for the combat sound cues confirmed by tests/sound.gd (hit/bell/reload/
# dodge/slash). main.gd's fire()/use_pulse()/spawn_well() call sound.play_sound() directly
# since they already have the relevant weapon id / kind in scope there.
signal sound_requested(kind: String, id: int)
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
var relics: Array = []
var relic_capacity := 3
var owned_relics: Array = []
var temporary_relic := -1
var telemetry
var state: Dictionary = {}
var char_id := -1
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
	$Animation.reset()
	relics.clear()
	owned_relics.clear()
	temporary_relic = -1
	# ai_cd: CPU-only dodge-roll cooldown (legacy makePlayer()'s p.ai=rnd(.25,.6); unused by
	# human players). Decremented only while a bullet threat is present, see cpu_ai.gd.
	state = {"pulses":initial_pulses,"pos":spawn,"hp":max_hp,"max_hp":max_hp,"angle":0.0,"shot":0.0,"roll":0.0,"dodge":0.0,"slash":0.0,"melee":0.0,"inv":0.0,"reload":0.0,"reload_slot":-1,"last_volley":-1,"blocked_volley":-1,"shield":0.0,"holster":0.0,"dir":Vector2.RIGHT,"gun":0,"ai_cd":randf_range(.25,.6)}
	inventory = [Weapons.new_inventory_entry(0)]
	update_weapon_art()
	sync_visual()
func hurt(amount: float, volley: int = -1, hazard: bool = false, origin: Dictionary = {}) -> bool:
	if state.roll > 0 or (volley >= 0 and state.blocked_volley == volley) or (state.inv > 0 and (volley < 0 or state.last_volley != volley)): return false
	if not hazard and 3 in relics and state.shield <= 0:
		state.blocked_volley = volley
		state.last_volley = -1
		state.shield = 12.0
		state.inv = .3
		ring_requested.emit(state.pos,Color("ffe2a0"),65.0)
		sound_requested.emit("bell",0)
		return false
	state.last_volley = volley
	var actual := minf(state.hp,amount)
	state.hp = maxf(0,state.hp-amount)
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
	if key == [KEY_E,KEY_K][i]: equip_slot((int(p.gun)+1) % inventory.size())
	if i == 0 and key >= KEY_1 and key <= KEY_4: equip_slot(key-KEY_1)
	if key == [KEY_R,KEY_P][i]: start_reload()
	if key == [KEY_SPACE,KEY_SHIFT][i] and p.dodge <= 0:
		p.last_volley = -1
		p.roll = dodge_duration
		p.dodge = dodge_cooldown
		p.inv = maxf(p.inv,dodge_invulnerability)
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
	p.melee = melee_cooldown
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
	var offset: Vector2 = enemy.state.pos-p.pos
	if offset.length() < melee_range and absf(wrapf(offset.angle()-p.angle,-PI,PI)) <= PI/3 and not arena.line_blocked(p.pos,enemy.state.pos): enemy.hurt(melee_damage)
func step(dt: float, i: int, enemy, arena, mouse_shooting: bool = false, ai: Dictionary = {}) -> bool:
	var p = state
	for timer in ["shot","roll","dodge","slash","melee","inv","shield","holster"]: p[timer] = maxf(0,p[timer]-dt)
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
	var shooting: bool = ai.shoot if not ai.is_empty() else (mouse_shooting if i == 0 else Input.is_physical_key_pressed(KEY_L))
	if shooting and weapon().clip == 0: start_reload()
	return shooting and can_fire()
func can_fire() -> bool:
	return state.shot <= 0 and state.reload <= 0 and state.roll <= 0 and weapon().clip > 0
func consume_shot() -> void:
	weapon().clip -= 1
	state.shot = definition().rate
	$Animation.fire()
func sync_visual() -> void:
	position = state.pos
	$Aim.rotation = state.angle
	$Identity.text = str(name)
	$Weapon.rotation = state.angle
	$Weapon/Sprite.flip_v = cos(state.angle) < 0
	$Slash.visible = state.slash > 0
	$Slash.rotation = state.angle
	$Animation.refresh()

func weapon() -> Dictionary:
	return inventory[state.gun]
func definition() -> Dictionary:
	return Weapons.definition(weapon().id)
func owns(id: int) -> bool:
	return inventory.any(func(w): return w.id == id)
func add_gun(id: int) -> bool:
	if not Weapons.supported(id) or owns(id) or inventory.size() >= 4: return false
	inventory.append(Weapons.new_inventory_entry(id))
	equip_slot(inventory.size()-1)
	return true
func equip_slot(index: int) -> void:
	if index < 0 or index >= inventory.size() or index == state.gun: return
	if 8 in relics and state.holster <= 0:
		var old := weapon()
		var old_def := Weapons.definition(old.id)
		if old.reserve > 0 and old.clip < int(old_def.mag):
			old.clip += 1
			old.reserve -= 1
			state.holster = 1.5
	state.gun = index
	state.reload = 0.0
	state.reload_slot = -1
	state.shot = maxf(state.shot, .15)
	update_weapon_art()
	sound_requested.emit("equip",0)
func start_reload() -> void:
	if state.reload > 0 or weapon().clip >= definition().mag or weapon().reserve <= 0: return
	state.reload = effective_reload_duration()
	state.reload_slot = state.gun
	sound_requested.emit("reload",0)
func finish_reload() -> void:
	if state.reload_slot != state.gun: return
	var w := weapon()
	var amount := mini(int(definition().mag)-int(w.clip), int(w.reserve))
	w.clip += amount
	w.reserve -= amount
	if amount > 0 and definition().get("switcher", false): w.mode = 1-w.mode
	state.reload_slot = -1
func update_weapon_art() -> void:
	$Weapon/Sprite.texture = Weapons.art(weapon().id)
	$Weapon/Sprite.scale = weapon_display_size / $Weapon/Sprite.texture.get_size()

# Field pickup rules are separate from strict shop purchases.
func acquire_weapon(id: int, replace: bool = false) -> String:
	if not Weapons.supported(id): return ""
	var g := Weapons.definition(id)
	for w in inventory:
		if w.id == id:
			var amount := mini(int(g.stock)-int(w.reserve),ceili(float(g.stock)*.6))
			if amount <= 0: return ""
			w.reserve += amount
			return g.name + "：予備弾を補給"
	if inventory.size() < 4:
		add_gun(id)
		return g.name + "：装備に追加"
	if not replace: return ""
	inventory[state.gun] = Weapons.new_inventory_entry(id)
	state.reload = 0.0
	state.reload_slot = -1
	state.shot = maxf(state.shot,.15)
	update_weapon_art()
	return g.name + "：装備中の武器と交換"
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
	if id in relics or id in owned_relics: return "所持済み"
	if relics.size() >= relic_capacity: return "レリック%d枠が満杯" % relic_capacity
	return ""
func add_relic(id: int) -> bool:
	if relic_block_reason(id) != "": return false
	relics.append(id)
	if id == 4:
		state.max_hp += 2.0
		state.hp = minf(state.max_hp,state.hp+2.0)
	return true
func effective_move_speed() -> float:
	return move_speed*(1.12 if 0 in relics else 1.0)
func effective_reload_duration() -> float:
	return reload_duration*(.65 if 1 in relics else 1.0)

func field_relic_reason(id: int) -> String:
	if temporary_relic >= 0: return "仮装備は1ラウンド1個まで"
	return relic_block_reason(id)
func acquire_temporary(id: int) -> bool:
	if field_relic_reason(id) != "" or not add_relic(id): return false
	temporary_relic = id
	return true
func apply_build(build: Dictionary, capacity: int, heal: bool = false) -> void:
	relic_capacity = capacity
	owned_relics = build.owned.duplicate()
	relics = build.equipped.duplicate()
	temporary_relic = -1
	state.max_hp = max_hp + (2.0 if 4 in relics else 0.0)
	state.hp = state.max_hp if heal else minf(state.hp,state.max_hp)
	if heal:
		inventory = [Weapons.new_inventory_entry(0)]
		state.gun = 0
		if build.main > 0: add_gun(build.main)
		state.shot = 0.0
		update_weapon_art()
