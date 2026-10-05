extends "res://scripts/ui/workshop_skin.gd"
# 2026-10-05: shop-specific fittings; adopted source atlas is kept unchanged.
const ACCESSORIES = preload("res://assets/ui/exploration/workshop/shop-accessories.png")
var accessory_parts: Dictionary = {}
var product: Texture2D
var supply_kind: String = ""
var purchase_time: float = -1.0
func _ready() -> void:
	super()
	accessory_parts = JSON.parse_string(FileAccess.get_file_as_string("res://assets/ui/exploration/workshop/shop-regions.json"))
func accessory(id: String, rect: Rect2) -> void:
	var r: Array = accessory_parts[id]
	draw_texture_rect_region(ACCESSORIES,rect,Rect2(r[0],r[1],r[2],r[3]))
func pipe(points: PackedVector2Array, power: float) -> void:
	draw_polyline(points,Color("9c8655"),8,true)
	draw_polyline(points,Color("213d36"),5,true)
	draw_polyline(points,Color(.4,1,.82,power),2,true)
func _draw() -> void:
	if parts.is_empty() or accessory_parts.is_empty(): return
	if not foreground:
		sprite("inner_backing",Rect2(118,134,884,550))
		var r: Array = parts.body_frame.region
		var xx: Array = [0,120,r[2]-120,r[2]]
		var yy: Array = [0,100,r[3]-100,r[3]]
		var dx: Array = [118,172,948,1002]
		var dy: Array = [134,188,630,684]
		for y in range(3):
			for x in range(3):
				draw_texture_rect_region(SHELL,Rect2(dx[x],dy[y],dx[x+1]-dx[x],dy[y+1]-dy[y]),Rect2(r[0]+xx[x],r[1]+yy[y],xx[x+1]-xx[x],yy[y+1]-yy[y]))
		draw_style_box(_well(),Rect2(190,242,258,300))
		return
	var power: float = smooth_progress((time-.4)/.5)*(.55+.08*sin(clock*2))
	pipe(PackedVector2Array([Vector2(295,640),Vector2(237,640),Vector2(237,535),Vector2(164,535),Vector2(164,294)]),power)
	if product != null or not supply_kind.is_empty():
		pipe(PackedVector2Array([Vector2(164,294),Vector2(164,222),Vector2(443,222),Vector2(443,460),Vector2(409,460)]),power)
	pipe(PackedVector2Array([Vector2(295,648),Vector2(591,648),Vector2(607,612),Vector2(624,612)]),power)
	pipe(PackedVector2Array([Vector2(591,648),Vector2(935,648),Vector2(969,529),Vector2(969,294)]),power)
	for x in [151,955]:
		sprite("tube",Rect2(x,265,28,253))
		for i in range(3):
			var y: float = 479-fposmod(clock*58+i*66,182)
			draw_line(Vector2(x+14,y),Vector2(x+14,y+10),Color(.6,1,.86,power),3,true)
	for x in [188,949]:
		accessory("housing",Rect2(x-37,580,74,73))
		var rotation: float = clock*.32+5*smooth_progress(time/1.3)+3*smooth_progress(maxf(0,purchase_time)/1.1)
		sprite("gear_large",Rect2(x-25,591,50,50),rotation*(1 if x==188 else -1))
		var r: Array = accessory_parts.housing
		draw_texture_rect_region(ACCESSORIES,Rect2(x-37,626.72,74,26.28),Rect2(r[0],r[1]+r[3]*.64,r[2],r[3]*.36))
	sprite("holder",Rect2(264,609,64,56))
	sprite("crystal",Rect2(282,620,28,29))
	sprite("latch",Rect2(532,112-smooth_progress(time/.3)*10,56,55))
	if product != null:
		accessory("plinth",Rect2(224,433,190,48))
		accessory("drawer",Rect2(269,552,98,40))
		var q: float = smooth_progress((purchase_time-.2)/.65)
		if q<1:
			var bounds := Vector2(250,200)*(1-q*.85)
			var scale_factor: float = minf(bounds.x/product.get_width(),bounds.y/product.get_height())
			var dim: Vector2 = product.get_size()*scale_factor
			var center := Vector2(318,350).lerp(Vector2(318,566),q)
			draw_texture_rect(product,Rect2(center-dim/2,dim),false)
	if supply_kind == "heal" and purchase_time<.85:
		accessory("plinth",Rect2(224,433,190,48))
		var q: float = smooth_progress((purchase_time-.2)/.65)
		draw_set_transform(Vector2(318,350).lerp(Vector2(318,566),q),0,Vector2.ONE*(4-3*q))
		draw_rect(Rect2(-13,-17,26,29),Color("302d29"))
		draw_rect(Rect2(-11,-15,22,25),Color("b6aa82"))
		draw_rect(Rect2(-3,-11,6,17),Color("c35346"))
		draw_rect(Rect2(-8,-6,16,6),Color("c35346"))
		draw_set_transform(Vector2.ZERO)
	for i in range(5):
		var age: float = fposmod(clock*1.1+i*.19,1)
		draw_circle(Vector2(296+sin(i*5.2)*age*19,631-age*30),1,Color(.7,1,.9,(1-age)*power*.5))
	var opened: float = smooth_progress((time-.25)/1.05)
	# Fixed-width leaves translate under the jamb. Sample only the visible source segment.
	var visible_width: float = 377*(1-opened)
	if visible_width>.1:
		var r: Array = accessory_parts.shutter
		var fraction: float = 1-opened
		draw_texture_rect_region(ACCESSORIES,Rect2(180,234,visible_width,311),Rect2(r[0]+r[2]*opened,r[1],r[2]*fraction,r[3]))
		draw_set_transform(Vector2(934,234),0,Vector2(-1,1))
		draw_texture_rect_region(ACCESSORIES,Rect2(0,0,visible_width,311),Rect2(r[0]+r[2]*opened,r[1],r[2]*fraction,r[3]))
		draw_set_transform(Vector2.ZERO)
	for x in [173,927]: accessory("rail",Rect2(x,225,17,330))
func _well() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("102a2b")
	style.border_color = Color("526653")
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	return style
