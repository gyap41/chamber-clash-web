extends Control
const SHELL = preload("res://assets/ui/exploration/workshop/shell.png")
const HUD = preload("res://assets/ui/exploration/workshop/hud-atlas.png")
const REGIONS = {
	"health":Rect2(48,106,763,146), "weapon":Rect2(845,94,640,261),
	"socket":Rect2(81,398,270,255), "action":Rect2(475,396,270,264),
	"boss":Rect2(837,489,639,89), "currency":Rect2(652,687,260,255)
}
var pause_menu: bool = false
var boss_visible: bool = false
static func texture(key: String) -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = HUD
	atlas.region = REGIONS[key]
	return atlas
static func draw_frame(canvas: CanvasItem, key: String, rect: Rect2) -> void:
	var region: Rect2 = REGIONS[key]
	var sx: float = 64
	var sy: float = 64
	var dx: float = 9
	var dy: float = 9
	if key == "health": sx=112; sy=40; dx=29; dy=12
	elif key == "weapon": sx=85; sy=65; dx=20; dy=16
	elif key == "boss": sx=64; sy=30; dx=22; dy=6
	var xs: Array = [0,sx,region.size.x-sx,region.size.x]
	var ys: Array = [0,sy,region.size.y-sy,region.size.y]
	var xx: Array = [rect.position.x,rect.position.x+dx,rect.end.x-dx,rect.end.x]
	var yy: Array = [rect.position.y,rect.position.y+dy,rect.end.y-dy,rect.end.y]
	for y in range(3):
		for x in range(3):
			canvas.draw_texture_rect_region(HUD,Rect2(xx[x],yy[y],xx[x+1]-xx[x],yy[y+1]-yy[y]),Rect2(region.position+Vector2(xs[x],ys[y]),Vector2(xs[x+1]-xs[x],ys[y+1]-ys[y])))
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
func frame(rect: Rect2) -> void:
	var r := Rect2(33,753,594,388)
	var xx: Array = [0,100,494,594]
	var yy: Array = [0,90,298,388]
	var dx: Array = [rect.position.x,rect.position.x+19,rect.end.x-19,rect.end.x]
	var dy: Array = [rect.position.y,rect.position.y+16,rect.end.y-16,rect.end.y]
	draw_rect(rect.grow(-6),Color("102b2be8"))
	for y in range(3):
		for x in range(3):
			if x==1 and y==1: continue
			draw_texture_rect_region(SHELL,Rect2(dx[x],dy[y],dx[x+1]-dx[x],dy[y+1]-dy[y]),Rect2(r.position.x+xx[x],r.position.y+yy[y],xx[x+1]-xx[x],yy[y+1]-yy[y]))
func _draw() -> void:
	draw_frame(self,"health",Rect2(22,26,268,52))
	draw_frame(self,"weapon",Rect2(802,690,296,86))
	for i in range(3): draw_frame(self,"socket",Rect2(952+i*48,22,42,45))
	draw_texture_rect(texture("currency"),Rect2(302,38,27,27),false)
	if boss_visible: draw_frame(self,"boss",Rect2(414,48,440,22))
	var ink := Color("d3c497")
	draw_polyline(PackedVector2Array([Vector2(962,34),Vector2(970,31),Vector2(978,35),Vector2(984,32),Vector2(984,51),Vector2(976,54),Vector2(969,50),Vector2(962,53),Vector2(962,34)]),ink,1.6,true)
	draw_line(Vector2(970,32),Vector2(970,50),ink,1.6,true)
	draw_line(Vector2(977,35),Vector2(977,52),ink,1.6,true)
	draw_rect(Rect2(1011,38,21,17),ink,false,1.6)
	draw_arc(Vector2(1021,38),6,PI,TAU,16,ink,1.6,true)
	draw_line(Vector2(1012,44),Vector2(1030,44),ink,1.6,true)
	for x in [1063,1072]: draw_rect(Rect2(x,35,4,19),ink)
	if pause_menu:
		draw_rect(Rect2(0,0,1120,800),Color(0,0,0,.32))
		frame(Rect2(400,240,320,265))
