extends "res://scripts/game/exploration.gd"
# Disposable playtest session: no encounter generation, rewards or progression persistence.
const Authored = preload("res://scripts/world/authored_rooms.gd")
const Registry = preload("res://scripts/catalog/enemy_registry.gd")
const EnemyScripts := Registry.ENEMIES
var lab_panel: PanelContainer
var lab_room: OptionButton
var lab_weapon: OptionButton
var lab_counts: Dictionary = {}
var lab_message: Label
var lab_invincible: CheckBox
var last_composition: Array = ["root_runner_prototype"]
var last_weapon := 0
var test_invincible := false
var room_ids: Array = []
var original_rina := false

func _ready() -> void:
 get_window().title="CHAMBER CLASH - 戦闘テスト"
 original_rina=preload("res://scripts/visuals/character_rig8.gd").enabled
 preload("res://scripts/visuals/character_rig8.gd").enabled=true
 room_catalog=Authored.catalog()
 for room in room_catalog.values(): room.doors.clear()
 for id in ["duel","workshop_trial","workshop_annex"]:
  var room=preload("res://scripts/world/room_template.gd").new()
  room.display_name={"duel":"対戦アリーナ","workshop_trial":"工房・主室","workshop_annex":"工房・別室"}[id]
  room.field=load("res://data/fields/"+id+".tres").duplicate(true)
  room_catalog["stage_"+id]=room
 start_room="courtyard"
 encounters_enabled=false;random_floor=false;preserve_room_dressing=true
 super._ready()
 create_lab_ui()
 for connection in hud.retry_requested.get_connections(): hud.retry_requested.disconnect(connection.callable)
 hud.retry_requested.connect(retry_lab)
 open_lab(true)

func _exit_tree() -> void:
 preload("res://scripts/visuals/character_rig8.gd").enabled=original_rina

func rebuild_doors() -> void:
 pass
func open_bag() -> bool:
 return false
func door_hint() -> String:
 return "F1 / Esc：テスト設定　 F5：再戦　 WASD：移動　左：射撃　右：近接　Space：回避"
func toggle_pause() -> void:
 if lab_panel != null: open_lab(not lab_panel.visible)
func open_lab(show_panel: bool) -> void:
 lab_panel.visible=show_panel
 set_pause_reason("lab",show_panel)
 if show_panel:
  lab_room.select(room_ids.find(start_room))
  lab_weapon.select(Weapons.SUPPORTED.find(last_weapon))
func _input(event: InputEvent) -> void:
 if event is InputEventKey and event.pressed and not event.echo:
  if event.keycode in [KEY_F1,KEY_ESCAPE]:
   toggle_pause();get_viewport().set_input_as_handled();return
  if event.keycode==KEY_F5:
   retry_lab();get_viewport().set_input_as_handled();return
 super._input(event)

func create_lab_ui() -> void:
 var layer:=CanvasLayer.new();layer.layer=25;add_child(layer)
 var quick:=Button.new();quick.text="F1 テスト設定";quick.position=Vector2(18,96);quick.size=Vector2(180,36);quick.focus_mode=Control.FOCUS_NONE
 quick.pressed.connect(func():open_lab(not lab_panel.visible));layer.add_child(quick)
 lab_panel=PanelContainer.new();lab_panel.position=Vector2(260,120);lab_panel.custom_minimum_size=Vector2(600,540);layer.add_child(lab_panel)
 var style:=StyleBoxFlat.new();style.bg_color=Color(.055,.075,.09,.98)
 style.set_content_margin_all(18);lab_panel.add_theme_stylebox_override("panel",style)
 var column:=VBoxContainer.new();column.add_theme_constant_override("separation",8);lab_panel.add_child(column)
 var heading:=Label.new();heading.text="戦闘テスト / リナ";heading.add_theme_font_size_override("font_size",24);column.add_child(heading)
 var note:=Label.new();note.text="設定中は停止。部屋移動・再戦でHPと弾薬をリセット。";column.add_child(note)
 lab_room=OptionButton.new();lab_room.focus_mode=Control.FOCUS_NONE;column.add_child(lab_room)
 room_ids=room_catalog.keys()
 for id in room_ids: lab_room.add_item(("ステージ / " if str(id).begins_with("stage_") else "部屋 / ")+room_catalog[id].display_name)
 lab_weapon=OptionButton.new();lab_weapon.focus_mode=Control.FOCUS_NONE;column.add_child(lab_weapon)
 for id in Weapons.SUPPORTED: lab_weapon.add_item("装備 / "+str(Weapons.definition(id).name))
 var grid:=GridContainer.new();grid.columns=4;grid.add_theme_constant_override("h_separation",12);column.add_child(grid)
 for id in EnemyScripts:
  var actor=EnemyScripts[id].new()
  var label:=Label.new();label.text=str(actor.spec.name).replace("（右下モーション試作）","（試作）");label.custom_minimum_size.x=200;grid.add_child(label);actor.free()
  var count:=SpinBox.new();count.min_value=0;count.max_value=6;count.step=1;count.custom_minimum_size.x=65;count.value=1 if id=="root_runner_prototype" else 0
  grid.add_child(count);lab_counts[id]=count
 lab_invincible=CheckBox.new();lab_invincible.text="リナを無敵にする（回避・観察用）";column.add_child(lab_invincible)
 var warning:=Label.new();warning.text="合計6体まで。苔玉は8方向の試作。専用SEは試聴調整中。";warning.add_theme_font_size_override("font_size",14);column.add_child(warning)
 lab_message=Label.new();lab_message.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;lab_message.custom_minimum_size=Vector2(540,44);column.add_child(lab_message)
 var actions:=HBoxContainer.new();column.add_child(actions)
 add_lab_button(actions,"この条件で開始",apply_lab)
 add_lab_button(actions,"敵なしで見学",func():
  for count in lab_counts.values(): count.value=0
  apply_lab())
 add_lab_button(actions,"続ける",func():open_lab(false))
 var extras:=HBoxContainer.new();column.add_child(extras)
 add_lab_button(extras,"全回復・弾薬補充",refill_lab)
 add_lab_button(extras,"同じ条件で再戦",retry_lab)
 add_lab_button(extras,"タイトルへ",return_to_title)

func add_lab_button(parent: Node, caption: String, action: Callable) -> void:
 var button:=Button.new();button.text=caption;button.focus_mode=Control.FOCUS_NONE;button.custom_minimum_size.y=34;button.pressed.connect(action);parent.add_child(button)
func apply_lab() -> void:
 var ids: Array=[]
 for id in lab_counts:
  for n in range(int(lab_counts[id].value)): ids.append(id)
 if ids.size()>6:
  lab_message.text="敵は合計6体までにしてください。";return
 test_invincible=lab_invincible.button_pressed
 launch_test(str(room_ids[lab_room.selected]),ids,int(Weapons.SUPPORTED[lab_weapon.selected]))
func retry_lab() -> void:
 launch_test(start_room,last_composition,last_weapon)
func refill_lab() -> void:
 if players[0].state.hp<=0:
  retry_lab();return
 players[0].state.hp=players[0].max_hp
 for i in range(players[0].inventory.size()): players[0].inventory[i]=players[0].new_weapon_entry(players[0].inventory[i].id)
 lab_message.text="HPと弾薬を補充しました。";refresh_hud()
func launch_test(room_id: String, ids: Array, weapon_id: int) -> bool:
 if not room_catalog.has(room_id) or ids.size()>6 or not Weapons.supported(weapon_id): return false
 for id in ids:
  if not EnemyScripts.has(id): return false
 start_room=room_id
 start_exploration(719)
 var player=players[0]
 player.inventory=[player.new_weapon_entry(weapon_id)];player.state.gun=0;player.update_weapon_art();player.sync_visual()
 var positions:=Encounter.spawn_positions(arena,player.state.pos,ids.size())
 if positions.size()!=ids.size():
  lab_message.text="この部屋には指定数を安全に配置できません。敵を減らしてください。"
  open_lab(true);return false
 for i in range(ids.size()):
  var actor=Encounter.ActorScene.instantiate();actor.set_script(EnemyScripts[ids[i]])
  arena.get_node("Players").add_child(actor);actor.prepare(positions[i]);actor.telemetry=telemetry
  players.append(actor);fighters.append(actor.state)
  participant_config.append({"id":"lab/enemy%d"%i,"team":"enemies","controller":"enemy"})
 roster.configure(participant_config)
 for i in range(1,players.size()): bind_combat_actor(i)
 last_composition=ids.duplicate();last_weapon=weapon_id
 exploration.encounter_status="active" if not ids.is_empty() else "none"
 lab_message.text=""
 open_lab(false);refresh_hud();return true

func _physics_process(dt: float) -> void:
 if exploration==null: return
 if phase=="play" and not paused and result.is_empty():
  if test_invincible: players[0].state.inv=maxf(players[0].state.inv,dt+.05)
  combat_visuals.step(dt);_step_pulse_effects(dt);combat.step(dt)
  for remains in get_tree().get_nodes_in_group("enemy_death_visuals"):
   if is_ancestor_of(remains): remains.step(dt)
  if players[0].state.hp<=0:
   result="リナが倒れました / F5で再戦、F1で設定";phase="result";clear_action_inputs();sound.stop_all()
  elif not players.slice(1).any(func(actor):return actor.state.hp>0): exploration.encounter_status="cleared"
 if not paused: FollowCamera.follow(arena.get_node("CombatCamera"),arena.field_rect,players[0].state.pos)
 arena.get_node("DangerZone").refresh(0.0)
 arena.get_node("CombatCamera").offset=-combat_visuals.shake_offset
 refresh_hud()
func refresh_hud() -> void:
 super.refresh_hud()
 hud.get_node("Root/Bag").disabled=true
 hud.get_node("Root/Heading").text="戦闘テスト ／ "+room_catalog[start_room].display_name
 hud.get_node("Root/Pause").disabled=false
 if paused: hud.get_node("Root/Status").text="停止中 · F1 / Escで設定・再開"
 elif exploration.encounter_status=="cleared": hud.get_node("Root/Status").text="全滅確認 · F5で再戦 / F1で部屋・敵を変更"
