extends Node2D
# Adapter around the real gameplay services. No match, AI, supplies, audio or run log.
const Session = preload("res://scripts/combat/combat_session.gd")
const Events = preload("res://scripts/combat/combat_events.gd")
const Roster = preload("res://scripts/combat/battle_roster.gd")
const PlayerScene = preload("res://scenes/combat/player.tscn")
const ArenaScene = preload("res://scenes/world/arena.tscn")
const Visuals = preload("res://scripts/visuals/combat_visuals.gd")
const Weapons = preload("res://scripts/catalog/weapon_catalog.gd")
const Command = preload("res://scripts/combat/combat_command.gd")
const projectile_scene = preload("res://scenes/combat/projectile.tscn")
const gravity_well_scene = preload("res://scenes/combat/gravity_well.tscn")
class SilentTelemetry extends RefCounted:
	func record(_kind: String, _data: Dictionary = {}) -> void: pass
var telemetry := SilentTelemetry.new()
var presentation := Events.new()
var roster := Roster.new()
var arena
var players: Array = []
var shots: Array = []
var wells: Array = []
var delayed_shots: Array = []
var volley_counter := 0
var origin_counter := 0
var phase := "play"
var paused := false
var result := ""
var fx
var session
var record: Dictionary
var conditions: Dictionary
var time := 0.0
var ticks := 0
var fired := false
var damage_total := 0.0
var source_position := Vector2(260,300)
var target_position := Vector2(650,300)
var image_sprite: Sprite2D
var bounds := Rect2(-90,-90,180,180)
var failure := ""
var seed_value := 0
func initialize(item: Dictionary, settings: Dictionary) -> void:
	record = item.duplicate(true); conditions = settings.duplicate(true)
	seed_value = int(settings.seed)
	# Reset randomness before each independent adapter; visual RNG is instance-owned.
	seed(seed_value)
	if record.method == "stage":
		_setup_arena(ResourceLoader.load(record.definition.path,"",ResourceLoader.CACHE_MODE_IGNORE))
		if arena != null: bounds = arena.field_rect
	elif record.method == "actor" and record.preview and not conditions.icon:
		var field = load("res://data/fields/duel.tres").duplicate(true)
		field.walls.clear(); field.walls.append(Rect2(1000,110,28,380)); field.walls.append(Rect2(92,110,28,380))
		if conditions.get("scenario","target")=="flight": field.walls.clear()
		if conditions.get("scenario","target")=="wall": field.walls=[Rect2(570,110,28,380)]
		_setup_arena(field)
		_setup_actors()
		bounds = Rect2(0,0,1120,600) if record.kind == "武器" and conditions.action in ["単発","連射"] and conditions.get("scenario","target")!="equipment" else Rect2(source_position-Vector2(105,100),Vector2(210,180))
	else:
		if not record.preview: failure = "未対応 / 定義・素材の診断を確認してください"
		_setup_image()
	queue_redraw()
func _setup_arena(field) -> void:
	if field == null or not field.has_method("validation_errors") or not field.validation_errors().is_empty():
		failure = "不正なFieldDefinition: プレビューを隔離しました"; return
	arena = ArenaScene.instantiate()
	# Strip active services and encounter participants before entering the tree.
	for path in ["Players/P1","Players/P2","Supplies","CombatCamera","CombatVisuals"]:
		var node = arena.get_node(path); node.get_parent().remove_child(node); node.free()
	var supplies_node := Node2D.new(); supplies_node.name = "Supplies"
	var spawn_node := Node2D.new(); spawn_node.name = "Spawns"; supplies_node.add_child(spawn_node); arena.add_child(supplies_node)
	arena.definition = field.duplicate(true)
	add_child(arena)
	arena.get_node("Floor").visible = record.method == "stage" or conditions.background == "実戦"
	arena.get_node("Walls").visible = record.method == "stage" or conditions.action in ["単発","連射"]
	fx = Visuals.new(); arena.add_child(fx); fx.rng.seed = seed_value; fx.shake_scale = 0.0
	presentation.emitted.connect(_event)
func _setup_actors() -> void:
	if arena == null: return
	var left := int(conditions.aim) == 1
	source_position = Vector2(860 if left else 260,300)
	target_position = Vector2(470 if left else 650,300)
	if conditions.get("scenario","target")=="flight": target_position=Vector2(560,-1000)
	if conditions.get("scenario","target")=="wall": target_position=Vector2(260 if left else 860,300)
	var available: Array = preload("res://scripts/catalog/character_catalog.gd").ids()
	if available.is_empty(): failure="装備を表示する対応キャラがありません"; return
	var character_id := int(record.definition.id) if record.kind == "キャラ" else int(available[0])
	var gun_id := int(record.definition.id) if record.kind == "武器" else int(conditions.weapon)
	roster.configure([{"id":"preview","team":"a","controller":"external"},{"id":"target","team":"b","controller":"external"}])
	session = Session.new(self)
	for i in range(2):
		var player = PlayerScene.instantiate(); player.name = "Preview" if i == 0 else "Target"
		arena.get_node("Players").add_child(player)
		player.set_character(character_id)
		player.reset(source_position if i == 0 else target_position)
		player.battle_roster = roster; player.battle_slot = i; player.combat_service = weakref(session)
		player.get_node("Identity").hide(); player.get_node("Aim").hide()
		player.visible = i == 0 or (record.kind == "武器" and conditions.action in ["単発","連射"])
		player.weapon_event_requested.connect(presentation.weapon_event)
		player.burst_requested.connect(presentation.burst); player.ring_requested.connect(presentation.ring)
		players.append(player)
		if i == 0 and Weapons.supported(gun_id) and not Weapons.definition(gun_id).is_empty():
			player.inventory = [Weapons.new_inventory_entry(gun_id)]; player.update_weapon_art()
		elif i == 0:
			failure = "装備武器が欠落・未対応: weapon:"+str(gun_id)+"。装備欄で選び直してください"
		player.state.angle = direction(conditions.aim).angle(); player.state.dir = direction(conditions.movement)
		player.sync_visual()
	if conditions.action == "リロード" and players[0].has_weapon():
		players[0].weapon().clip = 0; players[0].start_reload()
func _setup_image() -> void:
	if record.image.is_empty() or not FileAccess.file_exists(record.image):
		failure = "画像なし / 詳細から定義・使用元を確認できます"; return
	if record.kind == "レリック" and record.preview:
		var icon = preload("res://scripts/ui/hud_relic_icon.gd").new()
		icon.size = Vector2(28,28); icon.position = Vector2(-14,-14); add_child(icon)
		icon.configure(int(record.definition.id),1,false,0,false)
		bounds = Rect2(-14,-14,28,28); return
	var texture := load_image(record.image)
	if texture == null:
		failure = "画像読込失敗: 再インポート後にHubを再起動"; return
	image_sprite = Sprite2D.new(); image_sprite.texture = texture; add_child(image_sprite)
	if record.kind == "武器" and record.preview:
		image_sprite.texture = Weapons.art(int(record.definition.id))
		image_sprite.material = Weapons.Visuals.body_material(int(record.definition.id),Vector2(40,28))
	var ui_size := Vector2(40,28) if record.kind == "武器" else Vector2(24,24)
	if record.kind == "素材ファイル": ui_size = texture.get_size()
	image_sprite.scale = Vector2.ONE*minf(ui_size.x/texture.get_width(),ui_size.y/texture.get_height())
	bounds = Rect2(-ui_size*.5,ui_size)
static func load_image(path: String) -> Texture2D:
	if path.is_empty() or not FileAccess.file_exists(path): return null
	# Read source art lazily, including .gdignore material. Never keep an unbounded texture cache.
	if path.get_extension().to_lower() in ["png","svg"]:
		var image := Image.new()
		if image.load(ProjectSettings.globalize_path(path)) == OK: return ImageTexture.create_from_image(image)
	return null
static func direction(index: int) -> Vector2: return [Vector2.RIGHT,Vector2.LEFT,Vector2.DOWN,Vector2.UP][clampi(index,0,3)]
func advance(dt: float) -> void:
	time += dt; ticks += 1
	if players.is_empty(): return
	var player = players[0]
	var action: String = conditions.action
	var vector := direction(conditions.movement)
	if action not in ["単発","連射","リロード"]:
		player.state.angle = direction(conditions.aim).angle(); player.state.dir = vector
		player.state.roll = 0.0
		if action == "回避":
			var duration: float = player.dodge_duration
			var local_time := fposmod(time,1.2)
			if conditions.sync == "進捗": local_time = fposmod(time,1.2)/1.2*duration
			player.state.roll = maxf(0.0,duration-local_time)
		player.get_node("Animation").advance(dt,action == "歩行")
		player.sync_visual()
	else:
		var command := Command.idle(direction(conditions.aim).angle())
		command.shoot = action == "連射" or (action == "単発" and not fired)
		if player.step(dt,0,players[1],arena,false,command):
			session.fire(0); fired = true
		session._step_delayed_shots(dt)
		session._step_projectiles(dt)
		for well in wells:
			if not well.has_meta("hub_seed"):
				well.set_meta("hub_seed",seed_value)
				for emitter in well.get_node("LegendaryVisual").emitters: emitter.seed = seed_value+int(emitter.seed)
		session._step_wells(dt)
		# Target stays fixed and alive, but hit invulnerability and projectile rules are real.
		damage_total += maxf(0,players[1].max_hp-players[1].state.hp)
		players[1].state.hp = players[1].max_hp
		players[1].state.inv = maxf(0,players[1].state.inv-dt)
		if conditions.get("scenario","target")!="effect": players[1].state.pos = target_position
		players[1].sync_visual()
	fx.step(dt)
	queue_redraw()
func _event(kind: String, args: Array) -> void:
	if kind == "sound" or kind == "pulse": return
	if fx != null and fx.has_method(kind): fx.callv(kind,args)
func _draw() -> void:
	if conditions.is_empty(): return
	var backdrop := Color("17232c") if conditions.background == "暗" else Color("e5e9e7")
	draw_rect(Rect2(-12000,-12000,24000,24000),backdrop)
	if conditions.background == "透過":
		for x in range(-20,90):
			for y in range(-15,65):
				draw_rect(Rect2(x*24,y*24,24,24),Color("66717a") if (x+y)%2 else Color("9ba3a8"))
	elif conditions.background == "実戦" and arena == null:
		draw_texture_rect(preload("res://assets/first-workshop/floor.png"),Rect2(-560,-300,1120,600),false)
func finish() -> void:
	# Free synchronously so a reload cannot invalidate resources still being drawn.
	for child in get_children(): child.free()
	players.clear(); shots.clear(); wells.clear(); delayed_shots.clear()
	session = null; arena = null; fx = null
