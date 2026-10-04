extends Node2D
signal sound_requested(kind: String, id: int)
# Presentation only: does not own an actor, award loot, or block room clear.
var snapshot: Dictionary
var organic := false
var elapsed := 0.0
var moss_rig: Node2D
func _ready() -> void:
	if snapshot.get("enemy_id","")=="root_runner_prototype":
		moss_rig=preload("res://scripts/visuals/root_runner_rig.gd").new()
		add_child(moss_rig)
		moss_rig.view=snapshot.duplicate(true)
		moss_rig.view.death_time=0.0
		if snapshot.has("death_feet"):
			moss_rig.feet.assign(snapshot.death_feet)
			moss_rig.world=snapshot.death_world
			moss_rig.body_offset=snapshot.death_body_offset
			moss_rig.facing=snapshot.death_facing
			moss_rig.facing_index=snapshot.death_facing_index
const DURATION := 1.1
const BOSS_DURATION := 4.5
func step(dt: float) -> void:
	var before := elapsed
	elapsed += dt
	if moss_rig != null:
		moss_rig.view.death_time=elapsed
		moss_rig.modulate.a=1.0-smoothstep(.95,1.5,elapsed)
		moss_rig.queue_redraw()
	var boss: bool = snapshot.get("enemy_id","") == "furnace_warden"
	if boss:
		if before < .8 and elapsed >= .8: sound_requested.emit("boss_internal",0)
		if before < .22 and elapsed >= .22: sound_requested.emit("boss_internal",0)
		if before < 1.4 and elapsed >= 1.4: sound_requested.emit("boss_explosion",0)
	if elapsed >= (BOSS_DURATION if boss else 1.5 if moss_rig!=null else DURATION):
		queue_free()
		return
	queue_redraw()
func _draw() -> void:
	if is_queued_for_deletion() or snapshot.is_empty(): return
	var view := snapshot.duplicate()
	view.death_progress = minf(1,elapsed/.85)
	if view.get("enemy_id","") == "root_runner_prototype":
		draw_set_transform(Vector2.ZERO,0,Vector2(1,.45))
		draw_circle(Vector2.ZERO,17,Color(0,0,0,.24*(1-smoothstep(.95,1.5,elapsed))))
		draw_set_transform(Vector2.ZERO)
	elif view.get("enemy_id","") == "furnace_warden":
		preload("res://scripts/visuals/furnace_warden_visual.gd").paint_destruction(self,view,elapsed)
	elif view.get("enemy_id","") in ["ash_ram","triple_ring"]:
		preload("res://scripts/visuals/elite_machine_visual.gd").paint(self,view)
	elif view.get("enemy_id","") in ["runner_sentry","ram_sentry","ring_sentry"]:
		preload("res://scripts/visuals/sentry_variants_visual.gd").paint(self,view)
	elif view.get("enemy_id","") == "scatter_drone":
		preload("res://scripts/visuals/scatter_drone_visual.gd").paint(self,view)
	else:
		preload("res://scripts/visuals/enemy_sheet_visual.gd").paint(self,view,organic)
	# Fixed particles have no simulation/owner references or random gameplay effects.
	# A brief spark burst gives way to dust; organic remains shed quiet earthy motes.
	for particle in particles():
		if particle.spark:
			draw_line(particle.pos,particle.pos-particle.velocity*.035,particle.color,1.6,true)
		else:
			draw_circle(particle.pos,particle.radius,particle.color)

func particles() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for i in range(16 if not organic else 12):
		var spark := not organic and i < 6
		var start := .03 if spark else .22+float(i%4)*.045
		var duration := .34 if spark else .62
		var age := elapsed-start
		if age < 0 or age >= duration: continue
		var t := age/duration
		var angle := float(i)*2.399963
		var velocity := Vector2(cos(angle)*(50 if spark else 22),-34- float(i%3)*9)
		var origin := Vector2(cos(angle)*14,sin(angle)*5-5)
		var point := origin+velocity*age+Vector2(0,90 if spark else -8)*age*age
		var color := Color("ffc477") if spark else Color("a4ad77") if organic else Color("9a8b70")
		color.a = (1-t)*(1.0 if spark else .55)*minf(1,t*8)
		result.append({"pos":point,"velocity":velocity,"color":color,
			"radius":(1.2 if organic else 2.2)*(1+t),"spark":spark})
	return result
