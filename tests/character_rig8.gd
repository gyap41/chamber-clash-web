extends SceneTree
# 8方向キャラクターリグ（character_rig8.gd、リナで検証）: 既定は無効。有効時は待機・走行・回避を8方向の新しい描画に替え、他キャラは従来どおり。
const RunRig = preload("res://scripts/visuals/character_rig8.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	assert(not RunRig.enabled)
	var p = load("res://scenes/combat/player.tscn").instantiate()
	root.add_child(p)
	var anim = p.get_node("Animation")
	var parts = anim.get_node("StateMachine").parts
	var sprite: Sprite2D = p.get_node("Weapon/Sprite")
	p.set_character(0)
	p.reset(Vector2(300,300))
	p.add_gun(0)
	p.update_weapon_art()
	p.state.angle = 0.0
	p.sync_visual()
	assert(anim.rig_frame == -1 and parts.visible and sprite.visible)
	RunRig.enabled = true
	assert(RunRig.ensure_loaded() and RunRig.rig.views.size() == 5)
	# 8方向：向きと反転。側面・斜め前・正面は反転なし、左向き3方向だけ反転する。
	var expected := {0.0:["e","side",false],PI/4:["se","diag_front",false],PI/2:["s","front",false],3*PI/4:["sw","diag_front",true],
		PI:["w","side",true],-3*PI/4:["nw","diag_back",true],-PI/2:["n","back",false],-PI/4:["ne","diag_back",false]}
	for angle in expected:
		p.state.angle = angle
		anim.rig_dir = ""
		p.sync_visual()
		var e: Array = expected[angle]
		assert(anim.rig_dir == e[0] and anim.rig_view == e[1] and anim.rig_mirror == e[2])
		assert(anim.rig_action == "idle" and anim.rig_frame >= 0 and not parts.visible and not sprite.visible)
		assert(p.get_node("Weapon").visible and absf(angle_difference(p.get_node("Weapon").rotation,RunRig.visual_angle(angle))) < .00001)
		# grip（Weapon ローカル (8,0)）が手の位置に来る。
		var base: Transform2D = RunRig.base_transform(anim.pose,anim.rig_mirror)
		var grip: Vector2 = p.get_node("Weapon").transform*RunRig.GRIP_LOCAL
		assert(grip.distance_to(RunRig.hand(base,anim.rig_view,"idle",anim.rig_frame)) < .01)
		for action in ["run","idle","dodge"]:
			assert(RunRig.textures.has(e[1]+"-"+action+"-lower"))
	# 見た目の銃の角度：真下・真上だけ最大30°開き、水平・斜め45°はそのまま。
	assert(is_equal_approx(RunRig.visual_angle(0.0),0.0) and is_equal_approx(RunRig.visual_angle(PI/4),PI/4))
	assert(is_equal_approx(RunRig.visual_angle(PI/2),PI/2-deg_to_rad(30.0)))
	# 境界付近は前の向きを保つ（22.5°+8°まで）。
	assert(RunRig.select_dir(deg_to_rad(28.0),"e") == "e")
	assert(RunRig.select_dir(deg_to_rad(32.0),"e") == "se")
	assert(RunRig.select_dir(deg_to_rad(28.0),"") == "se")
	# 歩行位相6で8コマ一周。後退は逆順。
	p.state.angle = 0.0
	p.state.dir = Vector2.RIGHT
	var seen := {}
	for i in range(60):
		p.advance_visual(1.0/60,true)
		p.sync_visual()
		assert(anim.animation_name == "move" and anim.rig_frame >= 0 and not parts.visible)
		seen[anim.rig_frame] = true
	assert(seen.size() == 8)
	# 髪・スカーフ：側面はポニーテールとスカーフを別画像で持ち、走行中は毎フレームのばねで角度が動く。
	assert(RunRig.textures.has("side-pony") and RunRig.textures.has("side-scarf") and RunRig.textures.has("back-pony"))
	assert(anim.rig_swing.has("pony") and anim.rig_swing.has("scarf"))
	var before: float = anim.rig_swing.pony.angle
	for i in range(20):
		p.state.pos += Vector2.RIGHT*205.0/60.0
		p.advance_visual(1.0/60,true)
	assert(absf(anim.rig_swing.pony.angle-before) > .5 and absf(anim.rig_swing.pony.angle) <= RunRig.MAX_SWING+30.0)
	assert(RunRig.run_frame(1.5,false) == 2 and RunRig.run_frame(1.5,true) == 6)
	# 待機：呼吸の周期で8コマを巡回。
	assert(RunRig.idle_frame(0.0) == 0 and RunRig.idle_frame(float(RunRig.rig.idle_period)*.5) == 4)
	# 回避：移動方向で向きを選び、6コマを時間で進める。操作制限中は銃を隠し、両腕は前へ（free）。飛び込み中だけ浮く。
	assert(RunRig.dodge_frame(0.0) == 0 and RunRig.dodge_frame(.15) == 2 and RunRig.dodge_frame(.37) == 5)
	assert(RunRig.dodge_lift(0.0) == 0.0 and RunRig.dodge_lift(.15) > 5.0 and RunRig.dodge_lift(.3) == 0.0)
	p.state.angle = 0.0
	p.state.dir = Vector2.LEFT
	p.try_dodge()
	p.sync_visual()
	assert(anim.rig_action == "dodge" and anim.rig_frame == 0 and anim.rig_dir == "w" and anim.rig_mirror)
	assert(not p.get_node("Weapon").visible and not parts.visible)
	assert(RunRig.meta(anim.rig_view,"dodge",2).free and not RunRig.meta(anim.rig_view,"dodge",5).free)
	p.state.roll = 0
	p.advance_visual(.3,false)
	p.sync_visual()
	assert(anim.rig_action == "idle")
	# 近接（ナイフ）：押した瞬間から4コマ、照準方向で向きを選び、ナイフの画像と踏み込みがある。
	assert(RunRig.textures.has("melee") and RunRig.rig.views.side.actions.melee.size() == 4)
	assert(RunRig.melee_frame(0.0) == 0 and RunRig.melee_frame(.2) == 3 and RunRig.melee_lunge(0.0) == 0.0 and RunRig.melee_lunge(.13) > 6.0)
	p.state.angle = PI/2
	p.state.slash = .16
	p.sync_visual()
	assert(anim.rig_action == "melee" and anim.rig_frame == 0 and anim.rig_dir == "s")
	assert(not p.get_node("Slash").visible)
	for i in range(20):
		p.state.slash = maxf(0.0,p.state.slash-1.0/60)
		p.advance_visual(1.0/60,false)
	assert(anim.rig_action == "idle")
	# 当たり判定：距離64・左右70°（斬撃の弧も同じ扇形）
	assert(is_equal_approx(p.melee_range,64.0) and is_equal_approx(p.melee_arc,deg_to_rad(70.0)))
	# 登録（data/character_rigs.json）されたキャラだけが対象。
	assert(RunRig.has_rig(0) and not RunRig.has_rig(1))
	# 他キャラは対象外。
	p.set_character(1)
	p.reset(Vector2(300,300))
	p.sync_visual()
	assert(anim.rig_frame == -1 and parts.visible)
	# ゲーム中の切替キーは V（F8 は Godot エディターの実行停止と重なる）。同じ入力を複数の Actor が受けても1回だけ。
	p.set_character(0)
	p.reset(Vector2(300,300))
	var key := InputEventKey.new()
	key.keycode = KEY_V
	key.pressed = true
	anim._input(key)
	anim._input(key)
	assert(not RunRig.enabled and anim.rig_frame == -1 and parts.visible and sprite.visible)
	key = key.duplicate()
	anim._input(key)
	assert(RunRig.enabled and anim.rig_frame >= 0)
	# キャラの大きさ案D（C キー）：探索カメラ 1.2→1.45、リナの表示は足元を中心に1.1倍。既定は無効。
	var Camera = RunRig.Camera
	assert(not Camera.size_d and is_equal_approx(Camera.zoom(),1.2))
	var ck := InputEventKey.new(); ck.keycode = KEY_C; ck.pressed = true
	anim._input(ck); anim._input(ck)
	assert(Camera.size_d and is_equal_approx(Camera.zoom(),1.45))
	var b: Transform2D = RunRig.base_transform(Transform2D.IDENTITY,false)
	assert((b*Vector2(0,15)).is_equal_approx(Vector2(0,15)) and is_equal_approx(b.get_scale().x,1.1))
	Camera.toggle_size_d()
	assert(not Camera.size_d)
	RunRig.enabled = false
	p.queue_free()
	await process_frame
	print("PASS: 8-direction character rig (Rina; run/idle/dodge/melee) is off by default, selects 8 directions with mirroring, grip follows the hand")
	quit()
