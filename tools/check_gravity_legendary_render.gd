extends SceneTree
class Grid:
	extends Node2D
	func _draw() -> void:
		for y in range(15):
			for x in range(20):draw_rect(Rect2(x*40,y*40,40,40),Color("46545c") if (x+y)%2==0 else Color("53626b"))
func _initialize() -> void:call_deferred("run")
func snapshot() -> Image:
	await process_frame;await RenderingServer.frame_post_draw
	return root.get_texture().get_image()
func run() -> void:
	root.size=Vector2i(800,600);root.content_scale_size=root.size
	root.add_child(Grid.new())
	var wells=[]
	for i in range(4):
		var well=load("res://scenes/combat/gravity_well.tscn").instantiate();root.add_child(well)
		well.launch(Vector2(300+(i%2)*150,230+(i/2)*140),i);wells.append(well)
	for frame in range(25):
		for well in wells:well.step(.05,null,[],[])
		await snapshot()
	# Flush the final requested native particle step, then check that real frames cannot advance it.
	await snapshot();await snapshot()
	var frozen=await snapshot()
	for frame in range(8):await snapshot()
	var after=await snapshot()
	assert(frozen.get_data()==after.get_data(),"Particles or lens advanced while the combat clock was stopped")
	frozen.save_png("res://docs/art/reviews/gravity-legendary-2026-09-13/overlap-pause.png")
	for well in wells:well.step(.2,null,[],[])
	await snapshot();await snapshot()
	var resumed=await snapshot();assert(resumed.get_data()!=after.get_data())
	print("PASS: four overlapping lenses rendered; native particles and shaders freeze pixel-exactly and resume")
	quit()
