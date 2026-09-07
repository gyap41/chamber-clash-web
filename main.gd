extends Node2D
# Coordinates M1 only. Character/weapon catalog data is preserved, not yet applied.
@export var round_duration: float = 90.0
@export var projectile_scene: PackedScene = preload("res://scenes/projectile.tscn")
@onready var arena = $Arena
@onready var players: Array = [$Arena/Players/P1,$Arena/Players/P2]
@onready var hud = $HUD
var fighters: Array = [] # State views retained for the original regression API.
var shots: Array = []
var remaining: float
var result := ""
var paused := false
var catalog: Dictionary
func _ready() -> void:
	catalog = JSON.parse_string(FileAccess.get_file_as_string("res://data/catalog.json"))
	reset_round()
func reset_round() -> void:
	for b in shots:
		b.get_parent().remove_child(b)
		b.queue_free()
	shots.clear()
	fighters.clear()
	for i in range(2):
		players[i].reset(arena.get_node("Spawns/P%d" % [i+1]).position)
		fighters.append(players[i].state)
	remaining = round_duration
	result = ""
	paused = false
	hud.refresh(fighters,remaining,paused,result)
func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	if event.keycode == KEY_ENTER and result != "": reset_round()
	if event.keycode == KEY_ESCAPE: paused = not paused
	if paused or result != "": return
	for i in range(2): players[i].handle_key(event.keycode,i,shots,players[1-i])
func fire(index: int) -> void:
	if paused or result != "" or not players[index].can_fire(): return
	var bullet = projectile_scene.instantiate()
	arena.get_node("Projectiles").add_child(bullet)
	bullet.launch(players[index],index)
	players[index].consume_shot()
	shots.append(bullet)
func move_fighter(p: Dictionary, delta: Vector2) -> void:
	arena.move_fighter(p,delta)
func _physics_process(dt: float) -> void:
	if not paused and result == "":
		remaining -= dt
		for i in range(2):
			if players[i].step(dt,i,players[1-i],arena): fire(i)
		for b in shots: b.step(dt,arena,players[1-b.state.owner])
		for n in range(shots.size()-1,-1,-1):
			var b = shots[n]
			if b.state.dead or b.state.life <= 0:
				shots.remove_at(n)
				b.get_parent().remove_child(b)
				b.queue_free()
		if remaining <= 0 or fighters[0].hp <= 0 or fighters[1].hp <= 0:
			result = "DRAW" if fighters[0].hp == fighters[1].hp else ("P1 WINS" if fighters[0].hp > fighters[1].hp else "P2 WINS")
	hud.refresh(fighters,remaining,paused,result)
