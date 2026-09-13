extends Control
const Index = preload("res://tools/visual_hub/asset_index.gd")
const Store = preload("res://tools/visual_hub/conditions.gd")
const Registry = preload("res://tools/visual_hub/preview_registry.gd")
const Overlay = preload("res://tools/visual_hub/inspection_overlay.gd")
var index := Index.new()
var registry := Registry.new()
var state := Store.defaults()
var previews: Array = []
var visible_records: Array = []
var categories: ItemList
var results: ItemList
var details: RichTextLabel
var paths: ItemList
var path_values: Array = []
var comparison: ItemList
var grid: GridContainer
var count_label: Label
var status_label: Label
var time_label: Label
var output_label: Label
var search: LineEdit
var status_filter: OptionButton
var sort_filter: OptionButton
var action_filter: OptionButton
var weapon_filter: OptionButton
var time_input: SpinBox
var play_button: Button
var screen_button: Button
var controls: Dictionary = {}
var accumulator := 0.0
var replay_target := -1.0
var building := false
var save_clock := 0.0
var thumbnail_queue: Array = []
var thumbnail_generation := 0
var thumbnail_busy := false
var page_label: Label
const PAGE_SIZE = 48
func _ready() -> void:
	get_window().title = "Chamber Clash Visual Hub v1"
	get_window().min_size = Vector2i(1120,760)
	get_window().size = Vector2i(1440,940)
	get_window().content_scale_size = Vector2i(1440,940)
	state = Store.normalize(Store.read(Store.SETTINGS))
	var arguments:=OS.get_cmdline_user_args()
	if arguments.size()==2 and arguments[0]=="--conditions":
		var saved:=Store.read(arguments[1])
		if saved.get("conditions") is Dictionary: state=Store.normalize(saved.conditions)
	_build_ui()
	reload_index()
func _build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new(); background.color = Color("101a23"); background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(background)
	var margin := MarginContainer.new(); margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+side,14)
	add_child(margin)
	var root := VBoxContainer.new(); root.add_theme_constant_override("separation",10); margin.add_child(root)
	var heading := HBoxContainer.new(); root.add_child(heading)
	var title := _label(heading,"CHAMBER CLASH  /  VISUAL HUB",24); title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_button(heading,"再読み込み",reload_index)
	_button(heading,"条件を保存",save_conditions)
	_button(heading,"条件を復元",load_conditions)
	_button(heading,"PNG保存",capture)
	count_label = _label(root,"",15)
	var main := HBoxContainer.new(); main.size_flags_vertical = Control.SIZE_EXPAND_FILL; main.add_theme_constant_override("separation",12); root.add_child(main)
	var left := VBoxContainer.new(); left.custom_minimum_size.x = 165; main.add_child(left)
	_label(left,"探す",19)
	categories = ItemList.new(); categories.custom_minimum_size.y = 250; left.add_child(categories)
	categories.item_selected.connect(func(i): state.category = categories.get_item_metadata(i); state.page=0; _list())
	status_filter = _option(left,["すべて","現行","テスト","補助参照","未確認","原画・制作","履歴","要確認"],func(v): state.status=v; state.page=0; _list())
	_check(left,"原画・履歴も収集","files",false)
	_label(left,"比較対象（最大4件）",14)
	comparison = ItemList.new(); comparison.custom_minimum_size.y = 150; left.add_child(comparison)
	_button(left,"選択を比較に追加",add_compare)
	_button(left,"比較から外す",remove_compare)
	screen_button = _button(left,"比較を表示",toggle_screen)
	_button(left,"比較を空にする",func(): state.compare=[]; _comparison_list(); _rebuild_previews())
	var note := _label(left,"画像・定義は読取専用\n音声は再生しません\n\n緑：握り / 移動判定\n橙：銃口 / 弾判定\n水色：Spawn",13)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var center := VBoxContainer.new(); center.size_flags_horizontal = Control.SIZE_EXPAND_FILL; main.add_child(center)
	var find_row := HBoxContainer.new(); center.add_child(find_row)
	search = LineEdit.new(); search.placeholder_text = "名前・型付きID・武器タイプを検索"; search.size_flags_horizontal = Control.SIZE_EXPAND_FILL; find_row.add_child(search)
	search.text_changed.connect(func(value): state.query=value; state.page=0; _list())
	sort_filter = _option(find_row,["ID順","名前順","要確認順"],func(value): state.sort=["ID順","名前順","要確認順"].find(value); _list())
	results = ItemList.new(); results.custom_minimum_size.y = 168; results.max_columns = 4; results.same_column_width = true; results.fixed_column_width = 155; results.fixed_icon_size = Vector2i(44,44); results.icon_mode = ItemList.ICON_MODE_TOP
	results.add_theme_font_size_override("font_size",13); center.add_child(results)
	results.item_selected.connect(func(i):
		state.selected=visible_records[i].id
		if visible_records[i].method=="stage": state.fit=true; _restore_controls()
		_detail(); if_single_rebuild())
	results.item_activated.connect(func(_i): add_compare())
	var paging := HBoxContainer.new(); center.add_child(paging)
	_button(paging,"前の48件",func(): state.page=maxi(0,int(state.page)-1); _list())
	page_label=_label(paging,"",12); page_label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	_button(paging,"次の48件",func(): state.page=int(state.page)+1; _list())
	var transport := HFlowContainer.new(); center.add_child(transport)
	play_button = _button(transport,"再生",func(): state.playing=not state.playing; _play_label())
	_button(transport,"最初から",func(): state.time=0.0; _rebuild_previews())
	_button(transport,"1ステップ",func(): state.playing=false; _advance(float(state.dt)); _play_label())
	_option_key(transport,["0.25×","0.5×","1×","2×"],"speed",[.25,.5,1.0,2.0],false)
	time_label = _label(transport,"0.000 s",14)
	time_input = SpinBox.new(); time_input.min_value=0; time_input.max_value=30; time_input.step=.05; time_input.custom_minimum_size.x=90; transport.add_child(time_input)
	_button(transport,"秒へ移動",func(): state.time=time_input.value; state.playing=false; _rebuild_previews(true))
	var motion := HFlowContainer.new(); center.add_child(motion)
	action_filter = _option_key(motion,["待機","歩行","回避","単発","連射","リロード"],"action")
	_label(motion,"照準",13); _option_key(motion,["右","左","下","上"],"aim",[0,1,2,3])
	_label(motion,"移動",13); _option_key(motion,["右","左","下","上"],"movement",[0,1,2,3])
	_option_key(motion,["実時間","進捗"],"sync")
	var display := HFlowContainer.new(); center.add_child(display)
	_option_key(display,["暗","明","透過","実戦"],"background")
	_button(display,"等倍",func(): state.zoom=1.0; state.fit=false; _restore_controls(); _update_transforms())
	_option_key(display,["0.25倍","0.5倍","1倍","2倍","4倍","8倍"],"zoom",[.25,.5,1.0,2.0,4.0,8.0],false)
	_check(display,"枠に収める（形状比較）","fit",false)
	_check(display,"UIアイコン","icon")
	_check(display,"判定・握り・銃口","guides")
	var extras := HFlowContainer.new(); center.add_child(extras)
	_label(extras,"装備",13); weapon_filter=OptionButton.new(); weapon_filter.custom_minimum_size.x=185; extras.add_child(weapon_filter)
	weapon_filter.item_selected.connect(func(i): state.weapon=weapon_filter.get_item_metadata(i); _rebuild_previews())
	_label(extras,"seed",13)
	var seed_input := SpinBox.new(); seed_input.max_value=2147483647; seed_input.step=1; seed_input.custom_minimum_size.x=100; extras.add_child(seed_input); controls.seed=seed_input
	seed_input.value_changed.connect(func(v): if not building: state.seed=int(v); _rebuild_previews())
	_option_key(extras,["60Hz","120Hz"],"dt",[1.0/60.0,1.0/120.0])
	var stage := HFlowContainer.new(); center.add_child(stage)
	_option_key(stage,["俯瞰","実戦カメラ"],"camera")
	for pair in [["移動境界","movement_bounds"],["弾境界","bullet_bounds"],["Spawn","spawns"],["補給位置","supplies"]]: _check(stage,pair[0],pair[1])
	grid = GridContainer.new(); grid.columns=1; grid.size_flags_vertical=Control.SIZE_EXPAND_FILL; grid.size_flags_horizontal=Control.SIZE_EXPAND_FILL; grid.add_theme_constant_override("h_separation",8); grid.add_theme_constant_override("v_separation",8); center.add_child(grid)
	grid.resized.connect(_update_transforms)
	var right := VBoxContainer.new(); right.custom_minimum_size.x=292; main.add_child(right)
	_label(right,"詳細・修正先",19)
	details = RichTextLabel.new(); details.bbcode_enabled=false; details.selection_enabled=true; details.size_flags_vertical=Control.SIZE_EXPAND_FILL; details.custom_minimum_size=Vector2(292,180); details.add_theme_font_size_override("normal_font_size",13); right.add_child(details)
	_label(right,"参照パス（選択して操作）",14)
	paths = ItemList.new(); paths.custom_minimum_size=Vector2(292,190); paths.add_theme_font_size_override("font_size",12); right.add_child(paths)
	var actions := HBoxContainer.new(); right.add_child(actions)
	_button(actions,"コピー",func(): _path_action("copy"))
	_button(actions,"ファイル",func(): _path_action("file"))
	_button(actions,"フォルダ",func(): _path_action("folder"))
	status_label = _label(root,"",13); status_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	var output_row := HBoxContainer.new(); root.add_child(output_row)
	output_label=_label(output_row,"保存先: "+ProjectSettings.globalize_path(Store.DIRECTORY),12); output_label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	_button(output_row,"出力先を開く",func(): DirAccess.make_dir_recursive_absolute(Store.DIRECTORY); OS.shell_open(ProjectSettings.globalize_path(Store.DIRECTORY)))
func _label(parent: Node, text: String, font_size: int) -> Label:
	var label := Label.new(); label.text=text; label.add_theme_font_size_override("font_size",font_size); parent.add_child(label); return label
func _button(parent: Node, text: String, callback: Callable) -> Button:
	var button := Button.new(); button.text=text; button.add_theme_font_size_override("font_size",13); button.pressed.connect(callback); parent.add_child(button); return button
func _option(parent: Node, choices: Array, callback: Callable) -> OptionButton:
	var option := OptionButton.new(); option.add_theme_font_size_override("font_size",13)
	for choice in choices: option.add_item(str(choice))
	parent.add_child(option); option.item_selected.connect(func(i): if not building: callback.call(choices[i]))
	return option
func _option_key(parent: Node, choices: Array, key: String, values: Array = [], rebuild: bool = true) -> OptionButton:
	var mapping: Array = choices if values.is_empty() else values
	var option := _option(parent,choices,func(value):
		state[key]=mapping[choices.find(value)]
		if key=="action" and state.action in ["単発","連射"]:
			state.fit=true; _restore_controls()
		if rebuild: _rebuild_previews()
		else: _update_transforms())
	option.set_meta("values",mapping); controls[key]=option; return option
func _check(parent: Node, title: String, key: String, rebuild: bool = true) -> void:
	var check := CheckBox.new(); check.text=title; check.add_theme_font_size_override("font_size",13); parent.add_child(check); controls[key]=check
	check.toggled.connect(func(value):
		if building: return
		state[key]=value
		if key == "files": reload_index()
		elif rebuild: _rebuild_previews()
		else: _update_transforms())
func _restore_controls() -> void:
	building=true
	search.text=state.query
	status_filter.select(maxi(0,["すべて","現行","テスト","補助参照","未確認","原画・制作","履歴","要確認"].find(state.status)))
	sort_filter.select(clampi(int(state.sort),0,2))
	for key in controls:
		var control = controls[key]
		if control is CheckBox: control.button_pressed=state[key]
		elif control is SpinBox: control.value=state[key]
		elif control is OptionButton:
			var selected: int=control.get_meta("values").find(state[key])
			control.select(selected)
			if selected<0: control.text=str(state[key])+"（保存値）"
	for i in range(weapon_filter.item_count):
		if weapon_filter.get_item_metadata(i) == int(state.weapon): weapon_filter.select(i)
	for i in range(categories.item_count):
		if categories.get_item_metadata(i)==state.category: categories.select(i)
	building=false; _play_label()
func reload_index() -> void:
	_clear_previews()
	index.reload("res://data/catalog.json","res://data/weapon_visuals.json",state.files)
	index.install_game_snapshot()
	var counts := {}
	for record in index.records: counts[record.kind]=int(counts.get(record.kind,0))+1
	count_label.text="キャラ %d    武器 %d    レリック %d    ステージ %d    行動アイコン %d" % [counts.get("キャラ",0),counts.get("武器",0),counts.get("レリック",0),counts.get("ステージ",0),counts.get("行動アイコン",0)]
	categories.clear(); categories.add_item("すべて"); categories.set_item_metadata(0,"すべて")
	for kind in counts: categories.add_item("%s  %d" % [kind,counts[kind]]); categories.set_item_metadata(categories.item_count-1,kind)
	weapon_filter.clear()
	for item in index.enumerate("","武器"):
		if not item.preview: continue
		weapon_filter.add_item(item.name); weapon_filter.set_item_metadata(weapon_filter.item_count-1,int(item.definition.id))
	var missing: Array = []
	for id in state.compare:
		if not index.by_id.has(id): missing.append(id)
	state.compare=state.compare.filter(func(id): return index.by_id.has(id))
	if not index.by_id.has(state.selected):
		missing.append(state.selected); state.selected=index.records[0].id if not index.records.is_empty() else ""
	_list(); _comparison_list(); _detail(); _restore_controls(); _rebuild_previews(true)
	status_label.text=index.changes+"。JSONは再読込済み。画像変更はGodot再インポート＋Hub再起動、Scene・スクリプト変更はHub再起動が必要。"
	if not missing.is_empty(): status_label.text+=" 削除された対象: "+", ".join(missing)
	if not index.errors.is_empty(): status_label.text+=" 診断: "+" / ".join(index.errors)
func _list() -> void:
	visible_records=index.enumerate(state.query,state.category,state.status)
	visible_records.sort_custom(func(a,b):
		if int(state.sort)==1: return a.name.naturalnocasecmp_to(b.name)<0
		if int(state.sort)==2 and a.issues.size()!=b.issues.size(): return a.issues.size()>b.issues.size()
		return a.id.naturalnocasecmp_to(b.id)<0)
	var total := visible_records.size()
	state.page=clampi(int(state.page),0,maxi(0,ceili(float(total)/PAGE_SIZE)-1))
	visible_records=visible_records.slice(int(state.page)*PAGE_SIZE,(int(state.page)+1)*PAGE_SIZE)
	page_label.text="%d件  /  %d〜%d  （ページ内のみ画像読込）" % [total,int(state.page)*PAGE_SIZE+1 if total>0 else 0,mini(total,(int(state.page)+1)*PAGE_SIZE)]
	results.clear(); thumbnail_queue.clear(); thumbnail_generation+=1
	for item in visible_records:
		results.add_item(item.name+("  !" if not item.issues.is_empty() else ""))
		var n:=results.item_count-1
		results.set_item_tooltip(n,item.id+" / "+item.status)
		thumbnail_queue.append({"row":n,"path":item.image,"id":item.id,"kind":item.kind})
		if item.id==state.selected: results.select(n)
func _detail() -> void:
	paths.clear(); path_values.clear()
	var item := index.detail(state.selected)
	if item.is_empty(): details.text="対象なし"; return
	var lines: Array = [item.name,item.id+" / "+item.status,"", "定義: %s   素材: %s\nゲーム対応: %s   プレビュー: %s" % [_yes(item.defined),_yes(item.assets),_yes(item.game),_yes(item.preview)],"", "診断: "+("問題未検出" if item.issues.is_empty() else "\n"+"\n".join(item.issues))]
	if item.kind == "キャラ": lines.append("回避は実時間ではキャラ固有の長さ、進捗では1.2秒周期で正規化。移動は原点固定のモーション確認。")
	if item.kind == "武器": lines.append("単発・連射は実CombatSession。標的は位置/HPを維持。実寸は1倍、形状比較は枠に収める。UI表示は40×28px枠。")
	if item.method == "image": lines.append("行動24px、レリック実HUD部品28px枠（画像20px）、武器40×28px枠。素材ファイルは元画像の実寸。")
	if item.kind=="武器":
		var carriers: Array=preload("res://scripts/catalog/character_catalog.gd").ids()
		lines.append("装備キャラ: "+str(preload("res://scripts/catalog/character_catalog.gd").definition(int(carriers[0])).get("name","")) if not carriers.is_empty() else "装備キャラなし")
	lines.append("\n関連素材: "+", ".join(item.related))
	if not item.image.is_empty(): lines.append("画像: "+item.image)
	lines.append("\n定義\n"+JSON.stringify(item.definition,"  "))
	if item.has("profile"): lines.append("\n描画情報\n"+JSON.stringify(item.profile,"  "))
	lines.append("\n使用元\n"+"\n".join(item.users)+"\n"+str(item.get("usage_note","動的な使用元は参照パスの規則も確認してください")))
	details.text="\n".join(lines)
	for ref in item.references: _add_path(ref.path,ref.relation+" / "+ref.reason)
	for source in item.users: _add_path(source,"使用元（静的）")
func _yes(value: bool) -> String: return "あり" if value else "未確認 / なし"
func _add_path(path: String, description: String) -> void:
	paths.add_item(path.get_file()+"  ["+description.get_slice(" / ",0)+"]"); paths.set_item_tooltip(paths.item_count-1,path+"\n"+description); path_values.append(path)
func _path_action(action: String) -> void:
	if paths.get_selected_items().is_empty(): status_label.text="参照パスを選択してください"; return
	var path: String=path_values[paths.get_selected_items()[0]]
	if action=="copy": DisplayServer.clipboard_set(path); status_label.text="コピー: "+path
	else:
		var target:=ProjectSettings.globalize_path(path.get_base_dir() if action=="folder" else path)
		var error:=OS.shell_open(target)
		status_label.text=("開きました: " if error==OK else "開けませんでした: ")+target
func add_compare() -> void:
	if state.selected.is_empty() or state.compare.has(state.selected): return
	if state.compare.size()>=4: status_label.text="比較は最大4対象です。先に1件外してください"; return
	state.compare.append(state.selected); _comparison_list()
	if state.screen=="比較": _rebuild_previews()
func remove_compare() -> void:
	if comparison.get_selected_items().is_empty(): return
	state.compare.remove_at(comparison.get_selected_items()[0]); _comparison_list(); _rebuild_previews()
func _comparison_list() -> void:
	comparison.clear()
	for id in state.compare: comparison.add_item(str(index.detail(id).get("name",id))); comparison.set_item_tooltip(comparison.item_count-1,id)
func toggle_screen() -> void:
	if state.screen=="単体" and state.compare.size()<2: status_label.text="2〜4対象を比較へ追加してください"; return
	state.screen="比較" if state.screen=="単体" else "単体"; _rebuild_previews()
func if_single_rebuild() -> void:
	if state.screen=="単体": _rebuild_previews()
func _clear_previews() -> void:
	for preview in previews:
		preview.adapter.finish()
	previews.clear()
	if grid != null:
		for node in grid.get_children(): node.free()
func _rebuild_previews(restore_time: bool = false) -> void:
	if building or grid == null: return
	var target: float=state.time if restore_time else 0.0
	_clear_previews(); state.time=0.0; accumulator=0.0; replay_target=target if target>0 else -1.0
	var ids: Array=state.compare if state.screen=="比較" else [state.selected]
	grid.columns=2 if ids.size()>2 else maxi(1,ids.size())
	screen_button.text="単体へ戻る" if state.screen=="比較" else "比較を表示"
	for id in ids:
		var item:=index.detail(id)
		if item.is_empty(): continue
		var cell:=VBoxContainer.new(); cell.size_flags_horizontal=Control.SIZE_EXPAND_FILL; cell.size_flags_vertical=Control.SIZE_EXPAND_FILL; grid.add_child(cell)
		var heading:=_label(cell,item.name+"  /  "+id,13); heading.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS; heading.tooltip_text=heading.text
		var container:=SubViewportContainer.new(); container.stretch=true; container.size_flags_vertical=Control.SIZE_EXPAND_FILL; container.size_flags_horizontal=Control.SIZE_EXPAND_FILL; container.custom_minimum_size=Vector2(80,80); cell.add_child(container)
		var viewport:=SubViewport.new(); viewport.disable_3d=true; viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS; viewport.handle_input_locally=false; viewport.gui_disable_input=true; container.add_child(viewport)
		var adapter=registry.create_preview(viewport,item,state)
		var overlay:=Overlay.new(); overlay.adapter=adapter; adapter.add_child(overlay)
		if not adapter.failure.is_empty():
			var note:=_label(cell,adapter.failure,12); note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		previews.append({"adapter":adapter,"viewport":viewport,"container":container})
		container.resized.connect(_update_transforms)
	_update_transforms(); _play_label()
func _update_transforms() -> void:
	for preview in previews:
		var a=preview.adapter
		var size: Vector2=preview.container.size
		var zoom: float=state.zoom
		var center: Vector2=a.bounds.get_center()
		if state.fit: zoom=minf(size.x/maxf(a.bounds.size.x,1),size.y/maxf(a.bounds.size.y,1))*.85
		if a.record.method=="stage" and state.camera=="実戦カメラ":
			# Same fit extent as the game's 1120x800 combat canvas (HUD margins included).
			var field_scale := minf(1120.0/a.bounds.size.x,600.0/a.bounds.size.y)
			zoom=minf(size.x/1120.0,size.y/800.0)*field_scale
			center = Vector2(a.bounds.get_center().x,a.bounds.position.y+310.0/field_scale)
		preview.viewport.canvas_transform=Transform2D(0,Vector2.ONE*zoom,0,size*.5-center*zoom)
func _advance(dt: float) -> void:
	for preview in previews: preview.adapter.advance(dt)
	state.time+=dt
	time_label.text="%.3f s" % state.time
func _process(dt: float) -> void:
	if not thumbnail_busy and not thumbnail_queue.is_empty():
		var request: Dictionary=thumbnail_queue.pop_front()
		if request.kind=="ステージ" and DisplayServer.get_name()!="headless": _stage_thumbnail(request,thumbnail_generation)
		if not request.path.is_empty():
			var texture=Registry.Adapter.load_image(request.path)
			if texture != null:
				var small:=texture.get_image(); small.resize(64,maxi(1,int(64.0*small.get_height()/small.get_width())),Image.INTERPOLATE_LANCZOS)
				results.set_item_icon(request.row,ImageTexture.create_from_image(small))
	if replay_target>=0:
		if state.time+float(state.dt)*.5<replay_target: _advance(state.dt)
		else: replay_target=-1.0; _play_label()
	elif state.playing:
		accumulator+=dt*float(state.speed)
		var steps:=0
		while accumulator>=float(state.dt) and steps<8:
			_advance(state.dt); accumulator-=float(state.dt); steps+=1
		if state.time>=30: state.playing=false; _play_label()
	save_clock+=dt
	if save_clock>1.0: Store.save(Store.SETTINGS,state); save_clock=0
func _stage_thumbnail(request: Dictionary, generation: int) -> void:
	thumbnail_busy=true
	var viewport:=SubViewport.new(); viewport.size=Vector2i(128,80); viewport.disable_3d=true; viewport.render_target_update_mode=SubViewport.UPDATE_ONCE; add_child(viewport)
	var settings:=Store.defaults()
	var adapter=registry.create_preview(viewport,index.detail(request.id),settings)
	var factor:=minf(128/adapter.bounds.size.x,80/adapter.bounds.size.y)*.9
	viewport.canvas_transform=Transform2D(0,Vector2.ONE*factor,0,Vector2(64,40)-adapter.bounds.get_center()*factor)
	await RenderingServer.frame_post_draw
	if is_instance_valid(viewport):
		if generation==thumbnail_generation and request.row<results.item_count: results.set_item_icon(request.row,ImageTexture.create_from_image(viewport.get_texture().get_image()))
		adapter.finish(); viewport.queue_free()
	thumbnail_busy=false
func _play_label() -> void:
	play_button.text="一時停止" if state.playing else "再生"
	if replay_target>=0: play_button.text="再計算中"
	time_label.text="%.3f s" % state.time
func save_conditions() -> void:
	var path:=Store.unique_path("json")
	var error:=Store.save(path,{"version":1,"conditions":state,"catalog_hash":index.fingerprint,"engine":Engine.get_version_info().string,"renderer":"gl_compatibility"})
	status_label.text=("条件保存: " if error==OK else "保存失敗: ")+ProjectSettings.globalize_path(path)
func load_conditions() -> void:
	var dialog:=FileDialog.new(); dialog.access=FileDialog.ACCESS_FILESYSTEM; dialog.file_mode=FileDialog.FILE_MODE_OPEN_FILE; dialog.filters=PackedStringArray(["*.json ; 比較条件"]); dialog.current_dir=ProjectSettings.globalize_path(Store.DIRECTORY); add_child(dialog)
	dialog.file_selected.connect(func(path): restore_conditions(path); dialog.queue_free())
	dialog.canceled.connect(dialog.queue_free); dialog.popup_centered(Vector2i(850,550))
func restore_conditions(path: String) -> void:
	var saved:=Store.read(path)
	if not saved.get("conditions") is Dictionary:
		status_label.text="復元失敗: 条件JSONではありません"; return
	state=Store.normalize(saved.conditions); state.playing=false; reload_index()
	if saved.get("catalog_hash","")!=index.fingerprint: status_label.text+=" 保存時からデータ変更あり。現在の素材で再計算します。"
func capture() -> void:
	if replay_target>=0: status_label.text="再計算が終わってからPNGを保存してください"; return
	var was_playing: bool=state.playing; state.playing=false
	await RenderingServer.frame_post_draw
	var image:=get_viewport().get_texture().get_image()
	var pixel_scale := Vector2(image.get_size())/size
	var area := grid.get_global_rect()
	var rect:=Rect2i(area.position*pixel_scale,area.size*pixel_scale).intersection(Rect2i(Vector2i.ZERO,image.get_size()))
	var output:=image.get_region(rect)
	var path:=Store.unique_path("png"); DirAccess.make_dir_recursive_absolute(Store.DIRECTORY)
	var error:=output.save_png(path)
	var metadata:={"version":1,"conditions":state.duplicate(true),"catalog_hash":index.fingerprint,"png":path.get_file(),"engine":Engine.get_version_info().string,"renderer":"gl_compatibility","size":[output.get_width(),output.get_height()]}
	var saved:=Store.save(path.get_basename()+".json",metadata)
	status_label.text=("PNGと条件保存: " if error==OK and saved==OK else "保存失敗: ")+ProjectSettings.globalize_path(path)
	state.playing=was_playing
func _exit_tree() -> void:
	Store.save(Store.SETTINGS,state)
	_clear_previews()
