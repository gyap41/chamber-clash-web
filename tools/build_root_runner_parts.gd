extends SceneTree
const BASE := "res://assets/first-workshop/root-runner-prototype/"
func _initialize():
	build_moss()
	build_tackle()
	quit()

func build_moss():
	var raw := Image.load_from_file(ProjectSettings.globalize_path(BASE+"moss-parts-v1.png"))
	var boxes := {"body":Rect2i(0,0,480,500),"head":Rect2i(480,240,340,260),"upper":Rect2i(870,240,350,260),"lower":Rect2i(70,550,340,280),"jaw_l":Rect2i(510,550,250,280),"jaw_r":Rect2i(930,550,260,280),"antenna_l":Rect2i(90,890,350,340),"antenna_r":Rect2i(480,890,330,340)}
	var data := {}
	for key in boxes:
		var box: Rect2i = boxes[key]
		var low := box.end
		var high := box.position
		for y in range(box.position.y,box.end.y):
			for x in range(box.position.x,box.end.x):
				if raw.get_pixel(x,y).a > .1:
					low = low.min(Vector2i(x,y)); high = high.max(Vector2i(x+1,y+1))
		assert(high.x > low.x and high.y > low.y)
		data[key] = [low.x,low.y,high.x-low.x,high.y-low.y]
	var file := FileAccess.open(BASE+"moss-regions-v1.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(data,"\t")+"\n")
	print(data)

func build_tackle():
	var raw := Image.load_from_file(ProjectSettings.globalize_path(BASE+"tackle-parts-v1.png"))
	var boxes := {"head":Rect2i(60,330,340,220),"roll0":Rect2i(420,140,410,460),"roll1":Rect2i(850,140,400,460),"roll2":Rect2i(0,680,410,470),"roll3":Rect2i(420,680,410,470)}
	var data := {}
	for key in boxes:
		var box: Rect2i = boxes[key]
		var low := box.end
		var high := box.position
		for y in range(box.position.y,box.end.y):
			for x in range(box.position.x,box.end.x):
				if raw.get_pixel(x,y).a > .1:
					low=low.min(Vector2i(x,y));high=high.max(Vector2i(x+1,y+1))
		assert(high.x>low.x and high.y>low.y)
		data[key]=[low.x,low.y,high.x-low.x,high.y-low.y]
	var file := FileAccess.open(BASE+"tackle-regions-v1.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(data,"\t")+"\n")
	print(data)
