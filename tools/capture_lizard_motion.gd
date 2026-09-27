extends SceneTree
# Real-game motion check for the fire-pouch lizard (v3 art): the normal exploration loop at 60 steps/s in a
# generated room, the other enemies removed. Rina circles the lizard at a distance swinging across its
# 310px range, so it alternates chasing (walking) and attacking while turning through every direction.
# The camera follows the lizard and the HUD is hidden. Every 2nd step the area around the lizard is cropped. Outputs (in .local/lizard-motion/):
# frames/NNN.png, frames.txt (phase/row/column per frame), sheet.png (every 2nd saved frame) and
# player.html (flip-book at the real frame rate). Run: Godot --path . --script res://tools/capture_lizard_motion.gd
# Other enemies: add `-- --enemy=workshop_sentry` or `-- --enemy=quillback` (output .local/<id>-motion/).
# An enemy type missing from the room is spawned at the lizard's place the same way the encounter does.
# Always pass --quit-after (e.g. 9000): a script error stops run() before quit(), and the engine would idle.
const Sheet = preload("res://scripts/visuals/enemy_sheet_visual.gd")
const SEED := 22
const STEP := 1.0/60.0
const SECONDS := 26.0
const FRONT_SECONDS := 5.0
const CROP := Vector2i(220,170)
const ORBIT_RADIUS := 340.0
const ORBIT_SWING := 120.0
const ORBIT_SPEED := .6 # rad/s: one full turn around the lizard in about 10 s

func _initialize() -> void:
	call_deferred("run")

var OUT := "res://.local/lizard-motion/"
var target_id := "fire_pouch_lizard"

func run() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--enemy="):
			target_id = argument.trim_prefix("--enemy=")
			OUT = "res://.local/%s-motion/" % target_id
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT+"frames"))
	root.size = Vector2i(1120,800)
	root.content_scale_size = root.size
	preload("res://scripts/visuals/character_rig8.gd").enabled = true
	var game = load("res://scenes/game/exploration.tscn").instantiate()
	game.random_floor = true
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	game.start_exploration(SEED)
	game.set_pause_reason("focus",false)
	# Same entry as tests/fire_pouch_lizard.gd: the second normal room introduces the lizard.
	var ids: Array = game.floor_data.rooms.keys().filter(func(id): return game.floor_data.rooms[id].role == "normal")
	for index in range(2):
		game.Encounter.retire(game)
		var id: String = ids[index]
		game.exploration.enter_room(id,game.room_data(id).field.field_id)
		game.switch_field(game.room_data(id).field)
		game.Encounter.begin(game)
	var lizard = null
	for actor in game.players.slice(1):
		if actor.spec.id == target_id and lizard == null: lizard = actor
	if lizard == null:
		# Spawn the requested type next to the first enemy, registered like Encounter.begin.
		var script: Script = {"quillback":game.Encounter.Quillback,"workshop_sentry":game.Encounter.Actor,"fire_pouch_lizard":game.Encounter.Lizard}[target_id]
		lizard = game.Encounter.ActorScene.instantiate()
		lizard.set_script(script)
		lizard.name = "Enemy%d" % game.players.size()
		game.arena.get_node("Players").add_child(lizard)
		lizard.prepare(game.players[1].state.pos)
		lizard.telemetry = game.telemetry
		game.players.append(lizard)
		game.fighters.append(lizard.state)
		game.participant_config.append({"id":"motion/enemy","team":"enemies","controller":"enemy"})
		game.roster.configure(game.participant_config)
		game.bind_combat_actor(game.players.size()-1)
	for actor in game.players.slice(1):
		if actor != lizard: actor.state.hp = 0 # leave the target alone on screen; the others fall over and fade
	var player = game.players[0]
	player.max_hp = 999.0
	player.state.hp = 999.0
	game.get_node("HUD").visible = false
	var log := PackedStringArray()
	var frames: Array = []
	var steps := int(SECONDS/STEP)
	var last_pos: Vector2 = lizard.state.pos
	for i in range(steps):
		var t := i*STEP
		# Defeating the last enemy clears the room and frees the actor, so check before every access.
		var alive: bool = is_instance_valid(lizard) and lizard.state.hp > 0
		# Rina circles the lizard (teleported along the path; she is only the target).
		var target: Vector2 = last_pos+Vector2.from_angle(PI/2+t*ORBIT_SPEED)*(ORBIT_RADIUS+ORBIT_SWING*sin(t*.9))
		# Its route choice rarely points it straight down, so the last seconds hold Rina below it (front view).
		if t > SECONDS-2.0-FRONT_SECONDS: target = last_pos+Vector2(0,ORBIT_RADIUS+ORBIT_SWING*sin(t*.9))
		if alive and not game.arena.solid(target,16): player.state.pos = target
		player.state.hp = 999.0
		# The capture window is not focused, which pauses the game (focus reason); keep it running.
		for reason in game.pause_reasons.keys(): game.set_pause_reason(reason,false)
		# The end of the run shows a hit (flash) and the defeat (fall and fade).
		if alive and i == int((SECONDS-2.0)/STEP): lizard.hurt(.5)
		if alive and i == int((SECONDS-1.4)/STEP): lizard.hurt(99.0)
		game._physics_process(STEP)
		game.FollowCamera.follow(game.arena.get_node("CombatCamera"),game.arena.field_rect,last_pos,true)
		if i%2 != 0: continue
		await process_frame
		await RenderingServer.frame_post_draw
		var image: Image = root.get_texture().get_image()
		# After the defeat the actor is retired; keep the crop on the fading remains.
		if is_instance_valid(lizard) and lizard.state.hp > 0: last_pos = lizard.state.pos
		var screen: Vector2 = game.arena.get_global_transform_with_canvas()*last_pos
		var rect := Rect2i(int(screen.x)-CROP.x/2,int(screen.y)-CROP.y+50,CROP.x,CROP.y)
		rect = rect.intersection(Rect2i(Vector2i.ZERO,image.get_size()))
		var crop := Image.create(CROP.x,CROP.y,false,Image.FORMAT_RGBA8)
		crop.fill(Color(.1,.1,.1))
		if rect.size.x > 0 and rect.size.y > 0:
			var part := image.get_region(rect)
			part.convert(Image.FORMAT_RGBA8)
			crop.blit_rect(part,Rect2i(Vector2i.ZERO,rect.size),Vector2i.ZERO)
		var name := "%03d" % frames.size()
		assert(crop.save_png(OUT+"frames/"+name+".png") == OK)
		frames.append(crop)
		if not is_instance_valid(lizard) or lizard.state.hp <= 0:
			log.append("%s t=%.2f phase=defeated pos=%s" % [name,t,last_pos.round()])
			continue
		var view: Dictionary = lizard.enemy_visual_snapshot()
		var selected: Dictionary = Sheet.frame(view,target_id != "workshop_sentry")
		log.append("%s t=%.2f phase=%s row=%d col=%d moving=%.2f hit=%.2f pos=%s" % [name,t,lizard.attack_phase,selected.row,selected.column,float(view.get("motion",0)),float(view.get("hit",0)),lizard.state.pos.round()])
	var file := FileAccess.open(OUT+"frames.txt",FileAccess.WRITE)
	file.store_string("\n".join(log))
	file.close()
	# Contact sheet of every 2nd saved frame (15 per row).
	var picked: Array = []
	for i in range(0,frames.size(),2): picked.append(frames[i])
	var per_row := 15
	var rows := int(ceil(picked.size()/float(per_row)))
	var sheet := Image.create(per_row*CROP.x/2,rows*CROP.y/2,false,Image.FORMAT_RGBA8)
	for i in range(picked.size()):
		var small: Image = picked[i].duplicate()
		small.resize(CROP.x/2,CROP.y/2,Image.INTERPOLATE_BILINEAR)
		sheet.blit_rect(small,Rect2i(Vector2i.ZERO,small.get_size()),Vector2i((i%per_row)*CROP.x/2,(i/per_row)*CROP.y/2))
	assert(sheet.save_png(OUT+"sheet.png") == OK)
	var html := FileAccess.open(OUT+"player.html",FileAccess.WRITE)
	html.store_string("""<!doctype html><meta charset="utf-8"><title>Lizard motion</title>
<body style="background:#222;color:#ddd;font:14px sans-serif">
<p>火袋トカゲv3 本編ループ %d フレーム（30fps保存）。<button id=p>一時停止</button> <button id=s>コマ送り</button>
速度 <select id=r><option value=1>等速</option><option value=.5>1/2</option><option value=.25>1/4</option></select> <span id=i></span></p>
<img id=f width=440 style="image-rendering:pixelated">
<script>
var n=%d,k=0,run=true,log=%s;
function show(){document.getElementById('f').src='frames/'+String(k).padStart(3,'0')+'.png';document.getElementById('i').textContent=log[k]||'';}
function tick(){if(run){k=(k+1)%%n;show();}setTimeout(tick,1000/30/parseFloat(document.getElementById('r').value));}
document.getElementById('p').onclick=function(){run=!run;this.textContent=run?'一時停止':'再生';};
document.getElementById('s').onclick=function(){run=false;k=(k+1)%%n;show();};
show();tick();
</script>""" % [frames.size(),frames.size(),JSON.stringify(log)])
	html.close()
	print("frames=",frames.size())
	print("PASS: lizard motion captured")
	game.queue_free()
	await process_frame
	quit()
