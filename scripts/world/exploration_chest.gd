extends Node2D
signal landed
const BOSS_CHEST = preload("res://assets/sprites/boss/foundry-spinner/reward-v1/chest.png")
# Approved four-frame art; animation state is presentation only.
var reward: Dictionary
const OPEN_DURATION := .85
var opening := 0.0
var spawning := 0.0
var elapsed := 0.0
var landing := 0.0
func rarity_rank() -> int:
	var catalog = preload("res://scripts/catalog/relic_catalog.gd") if reward.get("kind","weapon") == "relic" else preload("res://scripts/catalog/weapon_catalog.gd")
	return maxi(0,["C","B","A","S"].find(str(catalog.definition(int(reward.get("item",0))).get("rarity","C"))))
func body_scale() -> float:
	return 1.0 if reward.get("source","") == "boss" else [1.0,1.15,1.3,1.5][rarity_rank()]
func rarity_color() -> Color:
	return [Color("d6ad6b"),Color("64bded"),Color("ffc36a"),Color("fff0b4")][rarity_rank()]
func _draw() -> void:
	if reward.get("source","") == "boss":
		paint_boss_chest()
		return
	var rank := rarity_rank()
	var tint := rarity_color()
	animate_body()
	draw_style_box(shadow(),Rect2(-24,2,48,13))
	paint_rarity_sprite()
	if rank > 0 and reward.state != "empty":
		for n in range(rank*3):
			var t := fposmod(elapsed*.3+n/float(rank*3),1.0)
			draw_circle(Vector2(sin(n*2.4)*27,-12-t*32),1,Color(tint,(1-t)*.65))
	if opening > 0:
		var t := 1.0-opening/OPEN_DURATION
		draw_arc(Vector2(0,-8),8+t*(24+rank*10),0,TAU,48,Color(tint,sin(t*PI)*.7),2,true)

	draw_set_transform(Vector2.ZERO)
	paint_burst()
	paint_item()
const CHEST_TEXTURES = [preload("res://assets/sprites/chests/rarity-v2/c.png"),preload("res://assets/sprites/chests/rarity-v2/b.png"),preload("res://assets/sprites/chests/rarity-v2/a.png"),preload("res://assets/sprites/chests/rarity-v2/s.png")]
# Measured by tools/chest_atlas.gd, alpha > .5 with 3px margin.
const CHEST_REGIONS = [
	[Rect2(63,142,521,398),Rect2(675,128,526,412),Rect2(74,696,500,456),Rect2(699,660,479,492)],
	[Rect2(60,152,532,440),Rect2(665,149,537,443),Rect2(64,699,523,456),Rect2(671,632,519,524)],
	[Rect2(95,164,485,398),Rect2(673,173,485,389),Rect2(95,712,486,406),Rect2(672,646,485,471)],
	[Rect2(61,93,508,447),Rect2(681,93,517,447),Rect2(63,696,504,470),Rect2(687,648,506,518)]]
func opening_frame() -> int:
	if reward.state == "closed": return 0
	if opening <= 0: return 3
	var time := OPEN_DURATION-opening
	if time < .12: return 0
	if time < .24: return 1
	if time < .38: return 2
	return 3
func paint_rarity_sprite() -> void:
	var rank := rarity_rank()
	var frame := opening_frame()
	var region: Rect2 = CHEST_REGIONS[rank][frame]
	var factor: float = 44.0/CHEST_REGIONS[rank][0].size.x
	var size: Vector2 = region.size*factor
	draw_texture_rect_region(CHEST_TEXTURES[rank],Rect2(Vector2(-size.x*.5,10-size.y),size),region)

func paint_burst() -> void:
	var rank := rarity_rank()
	var tint := rarity_color()
	if landing > 0:
		var t := 1.0-landing/.3
		for n in range(8):
			var angle := TAU*n/8.0
			var point := Vector2(cos(angle)*(18+t*22),8+sin(angle)*(5+t*7))
			draw_circle(point,2.5*(1-t),Color(tint,.35*(1-t)))
	if opening <= 0: return
	var t := clampf((OPEN_DURATION-opening-.24)/.61,0,1)
	if t <= 0: return
	var origin := Vector2(0,-18*body_scale())
	var flash := pow(1-t,3)
	draw_circle(origin,(12+rank*4)*(1+t),Color(tint,flash*.4))
	for n in range(8+rank*4):
		var angle := TAU*n/(8.0+rank*4)-PI/2
		var ray := Vector2.from_angle(angle)
		var point := origin+ray*(10+t*(26+rank*9))+Vector2(0,18*t*t)
		draw_line(point-ray*(3+rank),point,Color(tint,(1-t)*.8),1.5,true)

func shadow() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0,0,0,.35)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	return style
func step(dt: float) -> void:
	elapsed += dt
	landing = maxf(0,landing-dt)
	opening = maxf(0,opening-dt)
	var was_spawning := spawning > 0
	spawning = maxf(0,spawning-dt)
	if was_spawning and spawning == 0:
		landing = .3
		landed.emit()
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
	var shake := sin((OPEN_DURATION-opening)*48)*.035 if opening > OPEN_DURATION-.12 else 0.0
	var height := -44*sin(t*PI) if spawning > 0 else 0.0
	var appear := lerpf(.25,1.0,clampf(t*4,0,1)) if spawning > 0 else 1.0
	draw_set_transform(Vector2(0,height),shake,Vector2(1+squash,1-squash)*appear*body_scale())
	if spawning > 0:
		draw_arc(Vector2(0,5-height),18+t*46,0,TAU,40,Color(1,.75,.35,(1-t)*.65),3,true)

func paint_item() -> void:
	if reward.state != "open": return
	var t := 1.0-clampf(opening/OPEN_DURATION,0,1)
	var reveal := .2 if reward.get("source","") == "boss" else .45
	if t < reveal: return
	var flight := clampf((t-reveal)/(1-reveal),0,1)
	var target: Vector2 = reward.get("drop_offset",Vector2.ZERO)+Vector2(0,-16)
	var point := Vector2(0,-48).lerp(target,flight)+Vector2(0,-70*sin(flight*PI))
	if opening <= 0: point.y += sin(elapsed*3)*3
	var icon: Texture2D
	if reward.get("kind","weapon") == "relic":
		icon = preload("res://scripts/ui/hud_assets.gd").texture("relic_%02d" % int(reward.item))
	else:
		icon = preload("res://scripts/catalog/weapon_catalog.gd").pickup_art(reward.item)
	draw_circle(point,27.5,Color(1,.72,.24,.15))
	draw_set_transform(point,sin(flight*TAU)*.2)
	var icon_size := icon.get_size()
	# 2026-10-04: keep relic icons compact while preserving enlarged gun art.
	var longest: float = 32.0 if reward.get("kind","weapon") == "relic" else 52.0
	var display_size := icon_size*(longest/maxf(icon_size.x,icon_size.y))
	draw_texture_rect(icon,Rect2(-display_size*.5,display_size),false)
	draw_set_transform(Vector2.ZERO)
