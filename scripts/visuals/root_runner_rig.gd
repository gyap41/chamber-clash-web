extends Node2D
# Eight-direction prototype. World-space feet preserve stance contacts; combat owns attack timing.
const F := Vector2(0.70710678,0.70710678)
const S := Vector2(-0.70710678,0.70710678)
const STRIDE := 24.0
var textures: Dictionary = {}
var direction_anchors: Dictionary = {}
var direction_scale := 1.0
var facing := PI/4
var facing_index := 1
var feet: Array[Dictionary] = []
var world := Vector2.ZERO
var cycle := 0.0
var clock := 0.0
var view: Dictionary = {}
var guides := false
var body_offset := Vector2.ZERO

func _init() -> void:
	var atlas = load("res://assets/first-workshop/root-runner-prototype/moss-parts-v1.png")
	var regions = JSON.parse_string(FileAccess.get_file_as_string("res://assets/first-workshop/root-runner-prototype/moss-regions-v1.json"))
	for key in regions:
		var r: Array = regions[key]
		var tex := AtlasTexture.new()
		tex.atlas = atlas
		tex.region = Rect2(r[0],r[1],r[2],r[3])
		textures[key] = tex

	var tackle = load("res://assets/first-workshop/root-runner-prototype/tackle-parts-v1.png")
	var tackle_regions = JSON.parse_string(FileAccess.get_file_as_string("res://assets/first-workshop/root-runner-prototype/tackle-regions-v1.json"))
	for key in tackle_regions:
		var r: Array = tackle_regions[key]
		var tex := AtlasTexture.new()
		tex.atlas=tackle;tex.region=Rect2(r[0],r[1],r[2],r[3]);textures[key]=tex
	var directions=load("res://assets/first-workshop/root-runner-prototype/directions-v1.png")
	var data=JSON.parse_string(FileAccess.get_file_as_string("res://assets/first-workshop/root-runner-prototype/directions-regions-v1.json"))
	direction_scale=36.0/float(data.shell_width)
	for key in data.regions:
		var r=data.regions[key]
		var tex:=AtlasTexture.new()
		tex.atlas=directions;tex.region=Rect2(r[0],r[1],r[2],r[3])
		textures["direction"+key]=tex
		direction_anchors[key]=Vector2(data.anchors[key][0],data.anchors[key][1])
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	reset_pose()

func neutral(index: int) -> Vector2:
	var side := -1.0 if index < 3 else 1.0
	var slot := index%3
	var forward=Vector2.from_angle(facing)
	return forward*[-5.0,0.0,5.0][slot]+forward.orthogonal()*side*[10.0,12.0,10.0][slot]+Vector2(0,-2)

func reset_pose() -> void:
	facing=PI/4
	facing_index=1
	world = Vector2.ZERO
	cycle = 0
	body_offset=Vector2.ZERO
	feet.clear()
	for i in range(6):
		var initial := neutral(i)
		feet.append({"pos":initial,"start":initial,"goal":initial,"swing":false,"stopping":false,"p":0.0,"lift":0.0,"start_lift":0.0,"phase":0.0 if i in [0,2,4] else .5})

func advance(dt: float, displacement: Vector2, snapshot: Dictionary) -> void:
	clock += dt
	var previous_phase: String = view.get("phase", "")
	view = snapshot.duplicate()
	var facing_phase: String=view.get("phase","")
	var desired := facing
	if facing_phase=="chase" and displacement.length()>.001: desired=displacement.angle()
	elif facing_phase in ["windup","dash","recover"]: desired=float(view.get("angle",facing))
	# Hysteresis prevents boundary chatter; hidden rolling may turn immediately.
	if absf(angle_difference(facing,desired))>PI/8+.06:
		facing_index=posmod(int(round(desired/(PI/4))),8)
		facing=facing_index*PI/4
	world += displacement
	if view.get("phase","") == "recover" and (previous_phase == "dash" or displacement.length_squared() > .0001 or float(view.get("recovery",.9))-float(view.get("remaining",0)) <= .19):
		# Replant while fully tucked away, before the legs emerge at the new location.
		for i in range(6):
			feet[i].pos=world+neutral(i);feet[i].swing=false;feet[i].lift=0.0
			feet[i].phase=0.0 if i in [0,2,4] else .5
		cycle=0

	var moving: bool = displacement.length() > .001 and view.get("phase","") == "chase"
	if moving: cycle += displacement.length()/STRIDE
	for i in range(6):
		var foot: Dictionary = feet[i]
		var group_a := i in [0,2,4]
		var phase := fposmod(cycle+(0.0 if group_a else .5),1.0)
		var crossed: bool = phase >= .58 and (float(foot.phase) < .58 or phase < float(foot.phase))
		foot.phase=phase
		var displaced: bool = (foot.pos-world-neutral(i)).length()>12.0
		if moving and (crossed or displaced) and not foot.swing:
			foot.swing = true
			foot.start = foot.pos
			foot.goal = world+neutral(i)+displacement.normalized()*STRIDE*.45
			foot.stopping = false
			foot.p = 0.0
			foot.start_lift=0.0
		if foot.swing:
			if not moving and not foot.stopping:
				foot.start = foot.pos
				foot.goal = world+neutral(i)
				foot.p = 0.0
				foot.start_lift=foot.lift
				foot.stopping = true
			if foot.stopping: foot.p = minf(1,foot.p+dt*10)
			else:
				var pace := minf(displacement.length()/(STRIDE*.42),dt*220.0/maxf(1.0,foot.start.distance_to(foot.goal)))
				foot.p = minf(1,foot.p+pace)
			var t: float = foot.p
			foot.pos = foot.start.lerp(foot.goal,t*t*(3-2*t))
			foot.lift = lerpf(float(foot.start_lift),0,t) if foot.stopping else sin(t*PI)*1.8
			if t >= 1:
				foot.swing = false
				foot.lift = 0.0
	var weight_target := Vector2(sin(cycle*TAU)*.35,-absf(sin(cycle*TAU))*.65) if moving else Vector2.ZERO
	body_offset=body_offset.move_toward(weight_target,dt*8.0)
	queue_redraw()

static func attack_pose(snapshot: Dictionary) -> Dictionary:
	var curl := 0.0
	var roll := 0.0
	var lean := 0.0
	var hop := 0.0
	var phase: String = snapshot.get("phase","")
	var progress := float(snapshot.get("dash_progress",0))
	var turns := float(snapshot.get("roll_turns",progress))
	if phase == "windup":
		var elapsed := float(snapshot.get("windup",.65))-float(snapshot.get("remaining",0))
		curl = smoothstep(.06,.3,elapsed)
		lean = -3.0*sin(PI*smoothstep(.06,float(snapshot.get("windup",.5)),elapsed))
	elif phase == "dash":
		curl=1;roll=turns;hop=absf(sin(turns*TAU))*1.2
	elif phase == "recover":
		var elapsed := float(snapshot.get("recovery",.9))-float(snapshot.get("remaining",0))
		curl=1.0-smoothstep(.18,.45,elapsed)
		roll=lerpf(turns,ceilf(turns*4)/4,smoothstep(0,.18,elapsed))
		hop=absf(sin(turns*TAU))*1.2*(1.0-smoothstep(0,.12,elapsed))
		lean=sin(elapsed*25)*1.2*(1.0-smoothstep(.18,.6,elapsed))
	return {"curl":curl,"roll":roll,"lean":lean,"hop":hop}

func part(key: String, at: Vector2, width: float, pivot: Vector2, angle: float = 0.0, opacity: float = 1.0) -> void:
	var tex: Texture2D = textures[key]
	var factor := width/tex.get_width()
	draw_set_transform(at,angle,Vector2.ONE*factor)
	draw_texture(tex,-tex.get_size()*pivot,Color(1,1,1,opacity))
	draw_set_transform(Vector2.ZERO)

func leg_points(index: int, curl: float = 0.0) -> Array[Vector2]:
	var side := -1.0 if index < 3 else 1.0
	var forward:=Vector2.from_angle(facing)
	var hip: Vector2 = forward*[-5.0,0.0,5.0][index%3]+forward.orthogonal()*side*8.0+Vector2(0,-4)
	var foot: Dictionary = feet[index]
	var tip: Vector2 = (foot.pos-world-Vector2(0,float(foot.lift))).lerp(hip,curl)
	# A short outboard bend stays on its own side instead of orbiting a two-link IK circle.
	var knee := hip.lerp(tip,.55)+forward.orthogonal()*side*1.5*(1-curl)
	return [hip,knee,tip]

func leg(index: int, curl: float, opacity: float = 1.0) -> void:
	var side := -1.0 if index < 3 else 1.0
	var points := leg_points(index,curl)
	var hip := points[0]
	var knee := points[1]
	var tip := points[2]
	draw_line(hip,knee,Color(0.07,.23,.25,(1-curl)*opacity),3.5,true)
	draw_line(knee,tip,Color(.14,.35,.39,(1-curl)*opacity),3.0,true)
	part("upper",hip.lerp(knee,.6),4.5,Vector2(.5,.5),(knee-hip).angle(),(1-curl)*opacity)
	var toe_axis := (tip-knee).normalized().lerp(Vector2.from_angle(facing),.6).normalized()
	part("lower",tip,6.0,Vector2(.5,.5),toe_axis.angle(),(1-curl)*opacity)
	if guides: draw_circle(tip,1.3,Color.CORAL if feet[index].swing else Color.CYAN)

func _draw() -> void:
	if textures.is_empty(): return
	if not view.has("death_time"):
		draw_set_transform(Vector2.ZERO,0,Vector2(1,.45))
		draw_circle(Vector2.ZERO,17,Color(0,0,0,.24))
		draw_set_transform(Vector2.ZERO)
	var pose := attack_pose(view)
	var dying: bool=view.has("death_time")
	var fold := 0.0
	if dying:
		pose=view.get("death_pose",pose).duplicate()
		var t: float=view.death_time
		fold=.82*smoothstep(0,.22,t)
		# Preserve the exact live pose at t=0, then expose the side of the body.
		pose.curl=lerpf(float(pose.curl),0.0,smoothstep(.08,.32,t))
		pose.hop=float(pose.hop)*(1-smoothstep(0,.2,t))
		pose.lean=float(pose.lean)*(1-smoothstep(0,.2,t))
	var curl: float = pose.curl
	var death_blend := smoothstep(.12,.40,float(view.death_time)) if dying else 0.0
	var center := Vector2(0,-9)+body_offset*(1-curl)+Vector2.from_angle(facing)*float(pose.lean)-Vector2(0,float(pose.hop))
	if death_blend<1:
		# The domed shell occludes the sockets; only protruding feet remain visible.
		for i in range(6):
			leg(i,maxf(curl,fold),1-death_blend)
		direction_part(facing_index,center-Vector2.from_angle(facing)*curl*2.0,(1-smoothstep(.55,.95,curl))*(1-death_blend),1-.12*curl)
	if dying:
		direction_part(8,Vector2(0,-5),death_blend)
	if not dying and view.get("phase","")=="dash":
		var axis := Vector2.from_angle(float(view.get("angle",PI/4)))
		for i in range(3):
			var back := center-axis*(22+i*7)
			draw_line(back,back-axis*4,Color(.67,.72,.57,.22-float(i)*.05),1.2,true)
	if not dying and float(view.get("bounce_flash",0))>0:
		draw_arc(center,22,-.6,2.5,10,Color(.85,.8,.5,float(view.bounce_flash)*4),1.3,true)
	if curl > 0:
		var frame_position := fposmod(float(pose.roll)*4,4)
		var frame := int(floor(frame_position))
		var mix := smoothstep(0,1,frame_position-frame)
		var shell_alpha := smoothstep(.18,.65,curl)*(1-death_blend)
		part("roll%d"%frame,center,36,Vector2(.5,.5),0,shell_alpha)
		part("roll%d"%((frame+1)%4),center,36,Vector2(.5,.5),0,mix*shell_alpha)
	if guides: draw_arc(Vector2.ZERO,18,0,TAU,32,Color(1,1,1,.4),.5)

func direction_part(index: int, at: Vector2, opacity: float, tuck_scale: float = 1.0) -> void:
	var key:=str(index)
	draw_set_transform(at,0,Vector2.ONE*direction_scale*tuck_scale)
	draw_texture(textures["direction"+key],-direction_anchors[key],Color(1,1,1,opacity))
	draw_set_transform(Vector2.ZERO)
