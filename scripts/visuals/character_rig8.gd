extends RefCounted
## 8方向キャラクターリグの描画（2026-09-26、リナ v8 を一般化）。仮組み込み・既定は無効。
## ゲーム中の V キー（F8 は Godot エディターの実行停止と重なるため不可）、または起動引数 --rina-run で切替。
## data/character_rigs.json に登録されたキャラだけが対象（未登録のキャラは従来の素材のまま）。
## 素材と rig.json は tools/character_rig/build.py が設定ファイル（tools/character_rig/characters/<name>.json）から書き出す。
## 照準角で8方向を選び、左向き3方向は右向きの反転。向きごとの重なり順（rig.json の arms）で
## 体（下層）・銃・頭（上層）・腕を1つのCanvasItemへ描く。銃は本編 Weapon/Sprite の変換をそのまま使い、grip だけを手へ移す。
## 回避は移動方向で向きを選び、操作制限中は銃を隠して両腕を前へ伸ばす。
## 揺れ物（髪・布など、rig.json の parts）は体のシートに焼き込まず、毎フレームの減衰ばね（update_swing）で揺らし、
## 格子に分けて付け根から先へ向かって曲げて描く（draw_part）。布（cloth）は速さに応じてはためく。
const GRIP_LOCAL := Vector2(8,0) # player.gd の equipment_offset が grip を置く Weapon ローカル座標
const SECTORS := ["e","se","s","sw","w","nw","n","ne"] # 45°刻み（画面座標、下が＋）
const HYSTERESIS := 8.0 # 度。境界付近で向きがちらつかないよう、前の向きを保つ余裕
static var enabled := OS.get_cmdline_user_args().has("--rina-run")
static var last_toggle_event := 0
static var registry: Dictionary = {}
static var cache: Dictionary = {} # キャラID → {"rig":..., "textures":...}
# いま描いているキャラのリグ。select(id) で切り替える（描画は1体ずつ順に行うので共有してよい）。
static var rig: Dictionary = {}
static var textures: Dictionary = {}

static func toggle(event: InputEvent = null) -> void:
	# 同じ入力イベントを複数の Actor が受けても1回だけ切り替える。
	if event != null:
		if last_toggle_event == event.get_instance_id(): return
		last_toggle_event = event.get_instance_id()
	enabled = not enabled

static func has_rig(id: int) -> bool:
	if registry.is_empty():
		var parsed = JSON.parse_string(FileAccess.get_file_as_string("res://data/character_rigs.json"))
		registry = parsed.rigs if parsed is Dictionary else {"_":""}
	return registry.has(str(id))

## キャラIDのリグを読み込み、以後の描画対象にする。
static func select(id: int) -> bool:
	if not has_rig(id): return false
	if not cache.has(id):
		var dir: String = registry[str(id)]
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(dir+"rig.json"))
		if not parsed is Dictionary: return false
		var tex := {}
		for view in parsed.views:
			for action in parsed.views[view].actions:
				tex[view+"-"+action+"-lower"] = load(dir+view+"-"+action+"-lower.png")
				if parsed.views[view].upper: tex[view+"-"+action+"-upper"] = load(dir+view+"-"+action+"-upper.png")
			for part in parsed.views[view].parts:
				tex[view+"-"+part] = load(dir+view+"-"+part+".png")
		for key in parsed.get("arm_parts",{}):
			tex["arm-"+key] = load(dir+"arm-"+key+".png")
		if parsed.has("melee_weapon"): tex["melee"] = load(dir+"melee.png")
		cache[id] = {"rig":parsed,"textures":tex}
	rig = cache[id].rig
	textures = cache[id].textures
	return true

## 互換：最初に登録されたキャラ（リナ）を読み込む
static func ensure_loaded() -> bool:
	return select(0) if rig.is_empty() else true

static func active(id: int, alive: bool) -> bool:
	return enabled and alive and select(id)

## 照準角（ラジアン）から8方向。前の向きの中心から 22.5°+HYSTERESIS 以内なら保つ。
static func select_dir(angle: float, previous: String = "") -> String:
	if previous in SECTORS:
		var center := deg_to_rad(SECTORS.find(previous)*45.0)
		if absf(angle_difference(center,angle)) <= deg_to_rad(22.5+HYSTERESIS): return previous
	return SECTORS[posmod(roundi(rad_to_deg(angle)/45.0),8)]

## 方向 → [描き分けの向き, 左右反転]
static func view_of(dir: String) -> Array:
	return rig.mirror[dir]

## 見た目の銃の角度。正面・背面を向いて真下/真上を狙うと銃身が脚や頭を縦に覆うため、
## 垂直に近いほど最大 GUN_OPEN だけ画面右へ開いて、体の前で斜めに構えて見せる（弾の向きは変えない）。
## 長い武器（grip から銃口まで long_min 以上）は開くと銃床が頭の横まで上がるため、開き角を小さくする。
const GUN_OPEN := deg_to_rad(30.0)
const GUN_OPEN_LONG := deg_to_rad(18.0)
static func visual_angle(angle: float, long_gun: bool = false) -> float:
	var open := GUN_OPEN_LONG if long_gun else GUN_OPEN
	for v in [PI/2,-PI/2]:
		var d := absf(angle_difference(v,angle))
		if d < PI/4:
			var w := 1.0-d/(PI/4)
			return angle+(-open if v > 0 else open)*w
	return angle

## 武器が長いか（本編の Weapon/Sprite と武器の見た目定義から、grip→銃口の距離で判定）
static func is_long_gun(weapon_sprite: Sprite2D, weapon_id: int) -> bool:
	if weapon_sprite == null or weapon_sprite.texture == null or not ensure_loaded(): return false
	var profile: Dictionary = preload("res://scripts/catalog/weapon_visual_catalog.gd").profile(weapon_id).get("body",{})
	var muzzle_uv := Vector2(.98,.3)
	if profile.has("muzzle"): muzzle_uv = Vector2(float(profile.muzzle[0]),float(profile.muzzle[1]))
	var size := weapon_sprite.texture.get_size()*weapon_sprite.scale
	var muzzle_x: float = weapon_sprite.position.x+(muzzle_uv.x-.5)*size.x
	return muzzle_x-GRIP_LOCAL.x >= float(rig.arm.long_min)

## 走行：本編の歩行位相（6で1周期）を8コマへ。後退は逆順。
static func run_frame(move_phase: float, backpedal: bool) -> int:
	var f := posmod(floori(move_phase*8.0/6.0),8)
	return (8-f)%8 if backpedal else f

## 待機：呼吸の周期（rig.idle_period 秒）を8コマへ。
static func idle_frame(time: float) -> int:
	return posmod(floori(time/float(rig.idle_period)*8.0),8)

## 回避：経過時間（秒）から6コマ（踏み込み→踏み切り→飛び込み→着地前→着地→立ち直り）。
static func dodge_frame(time: float) -> int:
	var f := 0
	for t in rig.dodge_times:
		if time >= float(t): f += 1
	return f

## 近接の踏み込み（照準方向へ体をずらす量、ゲーム画素）。見た目だけで位置は動かさない。
const MELEE_LUNGE := 7.0
static func melee_lunge(time: float) -> float:
	return MELEE_LUNGE*sin(clampf(time/maxf(melee_duration(),.01),0,1)*PI)

## 近接：開始からの時間（秒）から4コマ。
static func melee_frame(time: float) -> int:
	var f := 0
	for t in rig.get("melee_times",[]):
		if time >= float(t): f += 1
	return f

static func melee_duration() -> float:
	return float(rig.get("melee_duration",0.26))

## 回避の飛び込み中の浮き（本編の旧回避と同じ 0.04〜0.26 秒の弧）。
static func dodge_lift(time: float) -> float:
	var start := float(rig.dodge_times[0])
	var finish := float(rig.dodge_times[3])
	if time < start or time >= finish: return 0.0
	return sin((time-start)/(finish-start)*PI)*float(rig.dodge_lift)

const Camera = preload("res://scripts/visuals/exploration_camera.gd")
static func base_transform(pose: Transform2D, mirrored: bool, lift: float = 0.0) -> Transform2D:
	# 案D（キャラの大きさの試験）では足元（y=foot_y）を中心に拡大する
	var k: float = Camera.CHAR_SCALE_D if Camera.size_d else 1.0
	var foot := Vector2(0,float(rig.foot_y) if not rig.is_empty() else 15.0)
	var size := Transform2D(0.0,Vector2(k,k),0.0,foot-foot*k)
	return Transform2D(0.0,Vector2(0,-lift))*pose*size*Transform2D(0.0,Vector2(-1 if mirrored else 1,1),0.0,Vector2.ZERO)

static func meta(view: String, action: String, frame: int) -> Dictionary:
	return rig.views[view].actions[action][frame]

static func point(view: String, action: String, frame: int, key: String) -> Vector2:
	var v: Array = meta(view,action,frame)[key]
	return Vector2(float(v[0]),float(v[1]))

static func hand(base: Transform2D, view: String, action: String, frame: int) -> Vector2:
	return base*point(view,action,frame,"hand")

## Weapon の位置を、grip が手に来るよう合わせる（Weapon の回転はそのまま）。
static func place_weapon(weapon: Node2D, base: Transform2D, view: String, action: String, frame: int, recoil: float) -> void:
	weapon.position = hand(base,view,action,frame)-weapon.transform.basis_xform(GRIP_LOCAL-Vector2(recoil*3.0,0))

## 2関節。既定は肘を画面の下側へ。out_from を渡すと、その x から遠い側（外側）へ肘を張る（背面・斜め後ろ）。
static func ik(a: Vector2, b: Vector2, l1: float, l2: float, out_from = null) -> Array:
	var d := a.distance_to(b)
	if d > l1+l2-.01:
		b = a+(b-a)*(l1+l2-.01)/d
		d = l1+l2-.01
	var t := (b-a).angle()
	var c := acos(clampf((l1*l1+d*d-l2*l2)/(2.0*l1*maxf(d,.001)),-1,1))
	var e1 := a+Vector2.from_angle(t+c)*l1
	var e2 := a+Vector2.from_angle(t-c)*l1
	if out_from != null:
		return [e1 if absf(e1.x-float(out_from)) >= absf(e2.x-float(out_from)) else e2, b]
	return [e1 if e1.y >= e2.y else e2, b]

static func color_of(values: Array, tint: Color) -> Color:
	return Color8(int(values[0]),int(values[1]),int(values[2]))*tint

static func capsule(canvas: CanvasItem, a: Vector2, b: Vector2, width: float, color: Color) -> void:
	canvas.draw_line(a,b,color,width,true)
	canvas.draw_circle(a,width*.5,color,true,-1.0,true)
	canvas.draw_circle(b,width*.5,color,true,-1.0,true)

static func sheet(canvas: CanvasItem, base: Transform2D, key: String, frame: int, color: Color) -> void:
	# key は "<向き>-<動作>-lower/upper"
	if not textures.has(key): return
	var k := float(rig.scale)
	var cell := Vector2(float(rig.cell[0]),float(rig.cell[1]))
	var origin := Vector2(float(rig.origin[0]),float(rig.origin[1]))
	canvas.draw_set_transform_matrix(base)
	canvas.draw_texture_rect_region(textures[key],Rect2(-origin*k+Vector2(0,float(rig.foot_y)),cell*k),Rect2(Vector2(frame*cell.x,0),cell),color)
	canvas.draw_set_transform_matrix(Transform2D.IDENTITY)

## 腕の部品（生成パーツ rina-arm-parts-v2）を回して描く。画像は左が付け根（肩/肘/手首）、右が先。
## 左向きに伸びる部品は上下を反転して、陰影と親指の向きを保つ。
static func draw_piece(canvas: CanvasItem, key: String, at: Vector2, dir: Vector2, length: float, tint: Color, anchor: float) -> void:
	if not textures.has("arm-"+key) or dir.length_squared() < 1e-6: return
	var size: Array = rig.arm_parts[key].size
	var w := length if length > 0.0 else float(size[0])
	var h := float(size[1])
	var d := dir.normalized()
	var xf := Transform2D(d.angle(),at)*Transform2D(0.0,Vector2(1,-1 if d.x < 0 else 1),0.0,Vector2.ZERO)
	canvas.draw_set_transform_matrix(xf)
	canvas.draw_texture_rect(textures["arm-"+key],Rect2(-w*anchor,-h*.5,w,h),false,tint)
	canvas.draw_set_transform_matrix(Transform2D.IDENTITY)

## 袖（肩→肘、肘→手首）。関節で隙間が出ないよう少し重ねる。
static func draw_sleeves(canvas: CanvasItem, shoulder: Vector2, joints: Array, tint: Color) -> void:
	var up: Vector2 = joints[0]-shoulder
	var low: Vector2 = joints[1]-joints[0]
	var hu := float(rig.arm_parts.sleeve_upper.size[1])
	var hl := float(rig.arm_parts.sleeve_lower.size[1])
	draw_piece(canvas,"sleeve_upper",shoulder,up,up.length()+hu*.6,tint,.3/(1.0+hu*.6/maxf(up.length(),.01)))
	draw_piece(canvas,"sleeve_lower",joints[0],low,low.length()+hl*.3,tint,.25/(1.0+hl*.3/maxf(low.length(),.01)))

## 手袋。握りは銃の向き、伸ばす手は前腕の向きへ回す。中心を手の点に置く。
static func draw_glove(canvas: CanvasItem, p: Vector2, key: String, dir: Vector2, tint: Color) -> void:
	draw_piece(canvas,key,p,dir,0.0,tint,.45)

# ---- 髪・スカーフの揺れ（二次動作） -------------------------------------------------------
# omega: 固有角速度(rad/s) / zeta: 減衰比 / drag: 前進の速さ（205px/s を1）で後ろへなびく角(度) /
# accel_x, accel_y: 付け根の加速度(px/s²)から角加速度(度/s²)への係数 / wind: ゆるやかな揺れの振幅(度)
const SWING := {
	"hair": {"omega":12.0,"zeta":.28,"drag":-10.0,"accel_x":-1.2,"accel_y":3.4,"wind":4.0},
	"cloth": {"omega":10.0,"zeta":.22,"drag":12.0,"accel_x":-1.2,"accel_y":3.0,"wind":5.5},
}
const MAX_SWING := 40.0 # 度。極端な入力でも毛束が裏返らない上限

## 毎フレームの更新。state は Actor ごとの辞書（player_animation が保持）。
## velocity: Actor の移動速度（Actor ローカル、ワールド画素/秒）。time: 経過時間（揺れの位相）。
static func update_swing(state: Dictionary, dt: float, view: String, action: String, frame: int, base: Transform2D,
		origin: Vector2, velocity: Vector2, mirrored: bool, time: float) -> void:
	if dt <= 0.0: return
	var fm := meta(view,action,frame)
	var yaw_k := absf(cos(deg_to_rad(float(rig.views[view].yaw))))
	var side_k := lerpf(.75,1.0,yaw_k) # 正面・背面は左右の揺れを少し控えめに
	var sign_x := -1.0 if mirrored else 1.0
	var speed := clampf(velocity.x*sign_x/205.0,-1.5,1.5)
	state["speed"] = clampf(velocity.length()/205.0,0.0,2.0)
	state["time"] = time
	# 向き・反転が変わった直後は付け根の位置が跳ぶので、加速度の履歴だけ捨てる（角度は保つ）
	var pose_key := view+("-m" if mirrored else "")
	if state.get("pose_key","") != pose_key:
		for part in state.keys():
			if state[part] is Dictionary:
				state[part].erase("root")
				state[part].erase("root_vel")
		state["pose_key"] = pose_key
	for part in rig.views[view].parts:
		var cfg: Dictionary = SWING[str(rig.views[view].parts[part].get("type","hair"))]
		var st: Dictionary = state.get(part,{"angle":0.0,"vel":0.0})
		var root_key: String = part+"_root"
		var root: Vector2 = origin+base*Vector2(float(fm[root_key][0]),float(fm[root_key][1]))
		var target := float(fm.bias.get(part,0.0))+float(cfg.drag)*speed*side_k
		# ゆるやかな揺れ：呼吸（2.6秒）に近い周期と、少し速い成分を重ねる
		target += float(cfg.wind)*(sin(time*2.4+(0.0 if str(rig.views[view].parts[part].get("type","hair")) == "hair" else 1.3))+.45*sin(time*4.1+.7))
		var torque := 0.0
		if st.has("root"):
			var v: Vector2 = (root-st.root)/dt
			if st.has("root_vel"):
				var a: Vector2 = ((v-st.root_vel)/dt).limit_length(6000.0)
				torque = float(cfg.accel_x)*a.x*sign_x*side_k+float(cfg.accel_y)*a.y
			st["root_vel"] = v
		st["root"] = root
		# 半陰的オイラー法を小さな刻みで（フレーム時間が長くても発散しない）
		var steps := maxi(1,ceili(dt/(1.0/120.0)))
		var h := dt/steps
		var w := float(cfg.omega)
		for i in range(steps):
			var acc := -w*w*(float(st.angle)-target)-2.0*float(cfg.zeta)*w*float(st.vel)+torque
			st["vel"] = float(st.vel)+acc*h
			st["angle"] = clampf(float(st.angle)+float(st.vel)*h,target-MAX_SWING,target+MAX_SWING)
		state[part] = st

## 揺れるパーツを格子に分けて描く。付け根から毛先へ向かって曲がりが大きくなり、スカーフははためく。
static func draw_part(canvas: CanvasItem, base: Transform2D, view: String, action: String, frame: int, part: String,
		state: Dictionary, color: Color) -> void:
	var key := view+"-"+part
	if not textures.has(key): return
	var tex: Texture2D = textures[key]
	var info: Dictionary = rig.views[view].parts[part]
	var fm := meta(view,action,frame)
	var root_tex := Vector2(float(info.root[0]),float(info.root[1]))
	var axis := Vector2(float(info.axis[0]),float(info.axis[1]))
	var length := float(info.length)
	var root := Vector2(float(fm[part+"_root"][0]),float(fm[part+"_root"][1]))
	var lean := deg_to_rad(float(fm.lean))
	var k := float(rig.scale)
	var st: Dictionary = state.get(part,{})
	var angle := float(st.get("angle",fm.bias.get(part,0.0)))
	var speed := float(state.get("speed",0.0))
	var time := float(state.get("time",0.0))
	var cloth: bool = str(info.get("type","hair")) == "cloth"
	var flutter := (3.0+5.0*minf(speed,1.5)) if cloth else 1.0
	var freq := (2.5+6.0*minf(speed,1.5)) if cloth else 1.2
	var size := tex.get_size()
	const NX := 6
	const NY := 6
	var grid := []
	for j in range(NY+1):
		var row := []
		for i in range(NX+1):
			var p := Vector2(size.x*i/NX,size.y*j/NY)
			var d := p-root_tex
			var s := clampf(d.dot(axis)/length,0.0,1.0)
			var bend := deg_to_rad(angle*(.35+.65*s)+flutter*s*sin(time*TAU*freq-4.0*s))
			row.append(base*(root+d.rotated(bend).rotated(lean)*k))
		grid.append(row)
	var colors := PackedColorArray([color])
	for j in range(NY):
		for i in range(NX):
			var pts := PackedVector2Array([grid[j][i],grid[j][i+1],grid[j+1][i+1],grid[j+1][i]])
			var uvs := PackedVector2Array([Vector2(float(i)/NX,float(j)/NY),Vector2(float(i+1)/NX,float(j)/NY),
				Vector2(float(i+1)/NX,float(j+1)/NY),Vector2(float(i)/NX,float(j+1)/NY)])
			canvas.draw_polygon(pts,colors,uvs,tex)

static func draw_parts(canvas: CanvasItem, base: Transform2D, view: String, action: String, frame: int, layer: String,
		state: Dictionary, color: Color) -> void:
	for part in rig.views[view].parts:
		if rig.views[view].parts[part].layer == layer:
			draw_part(canvas,base,view,action,frame,part,state,color)

# ---- 近接（ナイフ） ---------------------------------------------------------------------------
const MELEE_SWING := .14 # 振り抜きまでの時間（秒）。当たりは押した瞬間なので、最初から振りの途中を見せる
const TRAIL_TIME := .2   # 斬撃の弧が消えるまで

## 振りの角度：照準から -arc → +arc へ素早く振り抜き、その後は照準方向へ戻す。
static func melee_angle(aim: float, arc: float, t: float) -> float:
	var k := clampf(t/MELEE_SWING,0,1)
	k = 1.0-pow(1.0-k,3.0)
	var ang := aim-arc*.85+arc*1.7*k
	if t > MELEE_SWING:
		var r := clampf((t-MELEE_SWING)/maxf(melee_duration()-MELEE_SWING,.01),0,1)
		ang = lerpf(ang,aim,r*r)
	return ang

## ナイフを持つ腕（肩から振る向きへ伸ばす）とナイフ。
static func draw_melee_arm(canvas: CanvasItem, shoulder: Vector2, aim: float, arc: float, t: float, tint: Color) -> void:
	var ang := melee_angle(aim,arc,t)
	var d := Vector2.from_angle(ang)
	var reach := (float(rig.arm.upper)+float(rig.arm.lower))*(1.0 if t < MELEE_SWING else lerpf(1.0,.7,clampf((t-MELEE_SWING)/.1,0,1)))
	var hand_p := shoulder+d*reach
	var elbow := (shoulder+hand_p)*.5+d.orthogonal()*(1.5 if d.x >= 0 else -1.5)
	draw_sleeves(canvas,shoulder,[elbow,hand_p],tint)
	if textures.has("melee"):
		var mw: Dictionary = rig.melee_weapon
		var w := float(mw.size[0]); var h := float(mw.size[1])
		var xf := Transform2D(ang,hand_p)*Transform2D(0.0,Vector2(1,-1 if d.x < 0 else 1),0.0,Vector2.ZERO)
		canvas.draw_set_transform_matrix(xf)
		canvas.draw_texture_rect(textures["melee"],Rect2(-w*float(mw.grip_u),-h*.5,w,h),false,tint)
		canvas.draw_set_transform_matrix(Transform2D.IDENTITY)
	draw_glove(canvas,hand_p,"grip_side",d,tint)

## 斬撃の弧：当たり判定と同じ扇形（Actor の原点中心、半径 range、照準±arc）の外側を、振った所まで描いて消す。
static func draw_melee_trail(canvas: CanvasItem, aim: float, arc: float, radius: float, t: float, color: Color) -> void:
	if t >= TRAIL_TIME: return
	var fade := 1.0-t/TRAIL_TIME
	var a0 := aim-arc*.85
	var a1 := melee_angle(aim,arc,minf(t,MELEE_SWING))
	var steps := 14
	var outer := PackedVector2Array(); var inner := PackedVector2Array()
	for i in range(steps+1):
		var a := lerpf(a0,a1,float(i)/steps)
		var s := float(i)/steps # 振り終わり側ほど太く明るい
		outer.append(Vector2.from_angle(a)*radius)
		inner.append(Vector2.from_angle(a)*radius*lerpf(.85,.32,s)) # 内側は刃の位置からつながる
	var poly := PackedVector2Array(outer)
	for i in range(inner.size()-1,-1,-1): poly.append(inner[i])
	var c := Color(1,1,.94,.55*fade)*Color(1,1,1,color.a)
	canvas.draw_colored_polygon(poly,c)
	canvas.draw_polyline(outer,Color(1,1,1,.9*fade*color.a),1.2,true)

## canvas: Animation ノード。weapon_sprite が null または非表示なら銃と腕を描かない。
static func render(canvas: Node2D, base: Transform2D, view: String, action: String, frame: int, weapon_sprite: Sprite2D, weapon_id: int,
		show_weapon: bool, color: Color, swing: Dictionary = {}, melee: Dictionary = {}) -> void:
	# 呼び出し側（player_animation._draw）が向きの変換を設定したままなので、座標は Actor ローカルで描くよう解除する。
	canvas.draw_set_transform_matrix(Transform2D.IDENTITY)
	var arm: Dictionary = rig.arm
	var mode: Dictionary = rig.views[view]
	var fm := meta(view,action,frame)
	var free: bool = fm.get("free",false)
	# 回避中など銃を持たないコマは、両腕を記録された位置（前へ伸ばす）へ。
	var has_gun := show_weapon and not free and weapon_sprite != null and weapon_sprite.texture != null
	var has_arms := has_gun or free
	var grip := hand(base,view,action,frame)
	var support: Vector2 = base*point(view,action,frame,"hand_far") if free else grip
	var gun_xform := Transform2D.IDENTITY
	if has_gun:
		gun_xform = canvas.get_global_transform().affine_inverse()*weapon_sprite.get_global_transform()
		var weapon_xform: Transform2D = canvas.get_global_transform().affine_inverse()*weapon_sprite.get_parent().get_global_transform()
		var size := weapon_sprite.texture.get_size()*weapon_sprite.scale
		var sign_y := -1.0 if weapon_sprite.flip_v else 1.0
		var profile: Dictionary = preload("res://scripts/catalog/weapon_visual_catalog.gd").profile(weapon_id).get("body",{})
		var muzzle_uv := Vector2(.98,.3)
		if profile.has("muzzle"): muzzle_uv = Vector2(float(profile.muzzle[0]),float(profile.muzzle[1]))
		var muzzle_local: Vector2 = weapon_sprite.position+(muzzle_uv-Vector2(.5,.5))*size*Vector2(1,sign_y)
		var reach := muzzle_local.x-GRIP_LOCAL.x
		var local: Vector2
		if reach >= float(arm.long_min):
			local = Vector2(GRIP_LOCAL.x+minf(float(arm.support_max),reach*.4),muzzle_local.y*.88+sign_y*float(arm.glove_r)*.6)
		else:
			local = GRIP_LOCAL+Vector2(float(arm.pistol_support[0]),sign_y*float(arm.pistol_support[1]))
		support = weapon_xform*local
	var sn: Vector2 = base*point(view,action,frame,"shoulder_near")
	var sf: Vector2 = base*point(view,action,frame,"shoulder_far")
	var lower := view+"-"+action+"-lower"
	var upper := view+"-"+action+"-upper"
	var out_from = null
	if str(mode.get("elbow","down")) == "out": out_from = (base*Vector2.ZERO).x
	var near := ik(sn,grip,float(arm.upper),float(arm.lower),out_from)
	var far := ik(sf,support,float(arm.upper),float(arm.lower),out_from)
	var near_tint := color
	var far_tint := color*Color(.78,.74,.72) # 奥の腕は少し暗く
	# 手袋の種類と向き
	var gun_dir: Vector2 = gun_xform.x if has_gun else Vector2.ZERO
	var grip_key: String = {"side":"grip_side","diag_front":"grip_diag","front":"grip_front","diag_back":"grip_back","back":"grip_back"}.get(view,"grip_side")
	var far_key: String = grip_key
	if has_gun and support.distance_to(grip) > float(rig.arm_parts.grip_side.size[0])*.9 and not str(mode.arms) in ["front","behind"]:
		far_key = "support" # 長い武器：前の手は銃身の下から支える
	if free:
		grip_key = "reach_front" if view in ["front","back"] else "reach_side"
		far_key = grip_key
	var near_dir: Vector2 = gun_dir if has_gun else (near[1]-near[0])
	var far_dir: Vector2 = gun_dir if has_gun else (far[1]-far[0])
	var draw_near := func(with_hand: bool) -> void:
		draw_sleeves(canvas,sn,near,near_tint)
		if with_hand: draw_glove(canvas,near[1],grip_key,near_dir,near_tint)
	# 近接中は奥の手がナイフを振るので、銃を支える奥の腕は描かない
	var melee_on := action == "melee" and not melee.is_empty()
	var draw_far := func(with_hand: bool) -> void:
		if melee_on: return
		draw_sleeves(canvas,sf,far,far_tint)
		if with_hand: draw_glove(canvas,far[1],far_key,far_dir,far_tint)
	var draw_gun := func() -> void:
		if not has_gun: return
		var flip := Transform2D(0.0,Vector2(1,-1 if weapon_sprite.flip_v else 1),0.0,Vector2.ZERO)
		canvas.draw_set_transform_matrix(gun_xform*flip)
		var tex_size := weapon_sprite.texture.get_size()
		canvas.draw_texture_rect(weapon_sprite.texture,Rect2(-tex_size*.5,tex_size),false,weapon_sprite.modulate*color)
		canvas.draw_set_transform_matrix(Transform2D.IDENTITY)
	match str(mode.arms):
		"behind":
			# 背面・斜め後ろ：銃と両腕は体の後ろ。手は銃の上。
			# 肘は外へ張るので、体の脇から袖が見える（参考動画の背面）。
			if melee_on: draw_melee_arm(canvas,sf,float(melee.aim),float(melee.arc),float(melee.t),far_tint)
			draw_gun.call()
			if has_arms:
				draw_far.call(true)
				draw_near.call(true)
			draw_parts(canvas,base,view,action,frame,"behind",swing,color)
			sheet(canvas,base,lower,frame,color)
			draw_parts(canvas,base,view,action,frame,"front",swing,color)
			sheet(canvas,base,upper,frame,color)
			# 参考動画の背面：頭の上で銃を構えるので、両肩から袖が外・上へ張り出して見える。
			# 上腕の袖だけを体の上に重ね（肩から外へ約50°上向き）、前腕と手は頭の陰のまま。
			if has_arms:
				var center_x: float = (base*Vector2.ZERO).x
				for pair in [[sf,far_tint],[sn,near_tint]]:
					var sh: Vector2 = pair[0]
					var out_dir := Vector2(signf(sh.x-center_x) if absf(sh.x-center_x) > .01 else 1.0,0.0)
					var dir := (out_dir*.65+Vector2(0,-.76)).normalized()
					draw_piece(canvas,"sleeve_upper",sh,dir,float(rig.arm.upper)*1.4,pair[1],.3)
		"front":
			# 正面：体 → 銃 → 頭 → 両腕（手は銃の上）
			draw_parts(canvas,base,view,action,frame,"behind",swing,color)
			sheet(canvas,base,lower,frame,color)
			draw_parts(canvas,base,view,action,frame,"front",swing,color)
			draw_gun.call()
			sheet(canvas,base,upper,frame,color)
			if has_arms:
				draw_far.call(true)
				draw_near.call(true)
		_:
			# 側面・斜め前：遠側の腕 → 体 → 銃 → 頭 → 遠側の手 → 近側の腕
			if has_arms: draw_far.call(false)
			draw_parts(canvas,base,view,action,frame,"behind",swing,color)
			sheet(canvas,base,lower,frame,color)
			draw_parts(canvas,base,view,action,frame,"front",swing,color)
			draw_gun.call()
			sheet(canvas,base,upper,frame,color)
			if has_arms:
				if not melee_on: draw_glove(canvas,far[1],far_key,far_dir,far_tint)
				draw_near.call(true)
	# 近接：ナイフを持つ奥の腕（背面以外は体の上）と斬撃の弧（当たり判定と同じ扇形）
	if melee_on:
		if str(mode.arms) != "behind": draw_melee_arm(canvas,sf,float(melee.aim),float(melee.arc),float(melee.t),near_tint)
		draw_melee_trail(canvas,float(melee.aim),float(melee.arc),float(melee.range),float(melee.t),color)
