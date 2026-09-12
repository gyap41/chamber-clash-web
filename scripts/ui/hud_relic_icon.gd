extends "res://scripts/ui/relic_card.gd"
const Art = preload("res://scripts/ui/hud_assets.gd")
var relic_id := -1
var copies := 1
var temporary := false
var seconds := 0
var charged := false
var art: Texture2D
func configure(id: int, count: int, is_temporary: bool, cooldown: int, ready: bool) -> void:
	if relic_id == id and copies == count and temporary == is_temporary and seconds == cooldown and charged == ready: return
	relic_id = id
	copies = count
	temporary = is_temporary
	seconds = cooldown
	charged = ready
	art = Art.texture("relic_%02d" % id)
	queue_redraw()
func _draw() -> void:
	var area := Rect2(Vector2(4,4),size-Vector2(8,8))
	if art: draw_texture_rect(art,area,false,Color(1,1,1,.45 if seconds > 0 else 1.0))
	if charged: draw_rect(Rect2(Vector2(1,1),size-Vector2(2,2)),Color("ffe29b"),false,2)
	if temporary:
		for x in range(0,int(size.x)-3,8):
			draw_line(Vector2(x,1),Vector2(x+4,1),Color("dc9aff"),2)
			draw_line(Vector2(x,size.y-1),Vector2(x+4,size.y-1),Color("dc9aff"),2)
		draw_line(Vector2(1,1),Vector2(1,size.y-1),Color("dc9aff"),2)
		draw_line(Vector2(size.x-1,1),Vector2(size.x-1,size.y-1),Color("dc9aff"),2)
	var badge := "%ds" % seconds if seconds > 0 else ("×%d" % copies if copies > 1 else "")
	if not badge.is_empty():
		var font := ThemeDB.fallback_font
		var width := font.get_string_size(badge,HORIZONTAL_ALIGNMENT_LEFT,-1,12).x
		draw_rect(Rect2(Vector2(size.x-width-4,size.y-15),Vector2(width+4,15)),Color("101820"))
		draw_string(font,Vector2(size.x-width-2,size.y-3),badge,HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color.WHITE)
