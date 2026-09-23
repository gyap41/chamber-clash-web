extends Node2D
signal landed
const BOSS_CHEST = preload("res://assets/sprites/boss/foundry-spinner/reward-v1/chest.png")
# Temporary layered chest; animation state is presentation only.
var reward: Dictionary
const OPEN_DURATION := .85
var opening := 0.0
var spawning := 0.0
var elapsed := 0.0
func _draw() -> void:
	if reward.get("source","") == "boss":
		paint_boss_chest()
		return
	var lift := 0.0 if reward.state == "closed" else -sin((1-clampf(opening/OPEN_DURATION,0,1))*PI/2)*18
	animate_body()
	draw_style_box(shadow(),Rect2(-24,2,48,13))
	draw_rect(Rect2(-21,-13,42,26),Color("302c25"))
	draw_rect(Rect2(-19,-11,38,22),Color("84623d"))
	draw_rect(Rect2(-19,-11,38,7),Color("211f1b"))
	draw_rect(Rect2(-22,-20+lift,44,14),Color("ac8450"))
	draw_rect(Rect2(-22,-20+lift,44,3),Color("d6ad6b"))
	for x in [-17,13]: draw_rect(Rect2(x,-12,4,24),Color("b7a470"))
	if reward.state == "closed": draw_rect(Rect2(-4,-9,8,10),Color("dbc477"))

	draw_set_transform(Vector2.ZERO)
	paint_item()
func shadow() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0,0,0,.35)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	return style
func step(dt: float) -> void:
	elapsed += dt
	opening = maxf(0,opening-dt)
	var was_spawning := spawning > 0
	spawning = maxf(0,spawning-dt)
	if was_spawning and spawning == 0: landed.emit()
	queue_redraw()

func paint_boss_chest() -> void:
	var forming: bool = reward.state == "forming"
	if forming and reward.delay > 1.0: return
	var strength: float = 1.0-reward.delay if forming else 1.0
	if reward.state != "empty":
		draw_set_transform(Vector2(0,2),0,Vector2(1,.35))
		draw_circle(Vector2.ZERO,48,Color(1,.59,.15,.10*strength))
		draw_arc(Vector2.ZERO,40,0,TAU,48,Color(1,.75,.3,.3*strength),2,true)
		draw_set_transform(Vector2.ZERO)
		for n in range(12):
			var t := fposmod(elapsed*.65+n/12.0,1.0)
			var at := Vector2(sin(n*2.4)*34*(1-t),-t*64)
			draw_circle(at,1.5,Color(1,.8,.4,(1-t)*strength*.8))
	if forming: return
	var frame := 0 if reward.state == "closed" else (1 if opening > OPEN_DURATION-.18 else (3 if reward.state == "empty" else 2))
	var source := Rect2((frame%2)*654,0 if frame < 2 else 560,654,560 if frame < 2 else 641)
	draw_set_transform(Vector2(0,3),0,Vector2(1,.3))
	draw_circle(Vector2.ZERO,38,Color(0,0,0,.4))
	draw_set_transform(Vector2.ZERO)
	animate_body()
	# Common scale, separate row anchors; no per-frame silhouette fitting.
	var base := 513.0 if frame < 2 else 574.0
	var center := 342.0 if frame%2 == 0 else 315.0
	draw_texture_rect_region(BOSS_CHEST,Rect2(Vector2(-center*.14,-base*.14),source.size*.14),source)

	draw_set_transform(Vector2.ZERO)
	paint_item()

func animate_body() -> void:
	var t := 1.0-clampf(spawning/.4,0,1)
	var squash := sin(t*PI*3)*(1-t)*.3 if spawning > 0 else 0.0
	var shake := sin((OPEN_DURATION-opening)*32)*opening/OPEN_DURATION*.07 if opening > 0 else 0.0
	var height := -44*sin(t*PI) if spawning > 0 else 0.0
	var appear := lerpf(.25,1.0,clampf(t*4,0,1)) if spawning > 0 else 1.0
	draw_set_transform(Vector2(0,height),shake,Vector2(1+squash,1-squash)*appear)
	if spawning > 0:
		draw_arc(Vector2(0,5-height),18+t*46,0,TAU,40,Color(1,.75,.35,(1-t)*.65),3,true)

func paint_item() -> void:
	if reward.state != "open": return
	var t := 1.0-clampf(opening/OPEN_DURATION,0,1)
	if t < .2: return
	var flight := clampf((t-.2)/.8,0,1)
	var target: Vector2 = reward.get("drop_offset",Vector2.ZERO)+Vector2(0,-16)
	var point := Vector2(0,-48).lerp(target,flight)+Vector2(0,-70*sin(flight*PI))
	if opening <= 0: point.y += sin(elapsed*3)*3
	var icon: Texture2D
	if reward.get("source","") == "boss":
		icon = preload("res://scripts/ui/hud_assets.gd").texture("relic_%02d" % int(reward.item))
	else:
		icon = preload("res://scripts/catalog/weapon_catalog.gd").art(reward.item)
	draw_circle(point,27.5,Color(1,.72,.24,.15))
	draw_set_transform(point,sin(flight*TAU)*.2)
	draw_texture_rect(icon,Rect2(-20,-20,40,40),false)
	draw_set_transform(Vector2.ZERO)
