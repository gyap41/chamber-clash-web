extends SceneTree
const Snapshot = preload("res://scripts/visuals/actor_visual_state.gd")
const Controller = preload("res://scenes/visuals/actor_animation_state.tscn")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	# An enemy/preview can drive the exact controller without a Player or AI.
	var first = Controller.instantiate()
	var second = Controller.instantiate()
	root.add_child(first)
	root.add_child(second)
	var value := Snapshot.new()
	value.armed = true
	value.moving = true
	value.reload_remaining = .8
	first.present(value,false,.1)
	assert(first.body_state == &"move" and first.weapon_state == &"reload")
	assert(first.body_playback.get_current_node() == &"move")
	assert(first.weapon_playback.get_current_node() == &"reload")
	assert(second.body_state == &"idle" and second.weapon_state == &"disabled")
	var before: float = first.body_playback.get_current_play_position()
	first.present(value,false,.1)
	assert(first.body_playback.get_current_play_position() > before)
	before = first.body_playback.get_current_play_position()
	first.present(value,false) # Extra redraw/sync is not a simulation tick.
	assert(is_equal_approx(first.body_playback.get_current_play_position(),before))
	await process_frame
	await process_frame
	assert(is_equal_approx(first.body_playback.get_current_play_position(),before))
	value.dodge_remaining = .2
	value.dodge_action_locked = true
	first.present(value,false)
	assert(first.body_state == &"roll" and first.weapon_state == &"reload")
	assert(is_equal_approx(value.reload_remaining,.8))
	value.reload_remaining = 0
	value.dodge_action_locked = false # Rina's vulnerable landing permits fire.
	first.present(value,true)
	assert(first.body_state == &"roll" and first.weapon_state == &"fire")
	assert(value.weapon_visible())
	first.present(value,true,.05)
	assert(first.weapon_playback.get_current_play_position() > 0)
	first.restart_fire()
	assert(is_zero_approx(first.weapon_playback.get_current_play_position()))
	value.melee_active = true
	first.present(value,true)
	assert(first.weapon_state == &"melee")
	value.alive = false
	first.present(value,true)
	assert(first.body_state == &"dead" and first.weapon_state == &"disabled")
	assert(not value.weapon_visible())
	first.reset()
	assert(first.body_state == &"idle" and first.weapon_state == &"disabled")
	assert(is_zero_approx(first.body_playback.get_current_play_position()))
	first.free()
	second.free()

	var game = load("res://scenes/game/main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	preload("res://tests/helpers/battle.gd").passive_opponents(game)
	preload("res://tests/helpers/battle.gd").start(game)
	var p = game.players[0]
	var q = game.players[1]
	var anim = p.get_node("Animation")
	var machine = anim.get_node("StateMachine")
	var move := {"dx":1.0,"dy":0.0,"angle":0.0,"shoot":false}
	for id in range(8):
		p.set_character(id)
		p.reset(Vector2(350,450))
		p.add_gun(0)
		p.add_gun(4)
		p.equip_slot(0,false)
		p.state.shot = 0
		p.weapon().clip -= 1
		p.start_reload()
		p.step(.02,0,q,game.arena,false,move)
		assert(machine.body_state == &"move" and machine.weapon_state == &"reload")
		assert(anim.leg_step != 0 and not anim.reload_event.is_empty())
		var combat_before: Dictionary = p.state.duplicate(true)
		var inventory_before: Array = p.inventory.duplicate(true)
		p.sync_visual()
		assert(p.state == combat_before and p.inventory == inventory_before)
		# Presentation snapshots are detached from the actor's mutable state.
		var detached = p.visual_snapshot()
		var direction_before: Vector2 = detached.direction
		p.state.dir = Vector2.LEFT
		assert(detached.direction == direction_before)
		p.try_dodge()
		p.sync_visual()
		assert(machine.body_state == &"roll" and machine.weapon_state == &"reload")
		assert(not p.get_node("Weapon").visible)
		# Reload cancellation by queued equipment switch, then landing fire.
		p.request_switch(1)
		p.step(.311 if id == 0 else .261,0,q,game.arena,false,move)
		assert(p.state.gun == 1 and p.state.reload == 0)
		assert(anim.reload_event.is_empty() and machine.weapon_state == &"ready")
		assert(p.can_fire() and p.get_node("Weapon").visible)
		p.consume_shot()
		assert(machine.weapon_state == &"fire")
		assert(machine.body_state == (&"roll" if id == 0 else &"move"))
		p.step(.2,0,q,game.arena,false,move)
		assert(machine.body_state == &"move" and machine.weapon_state == &"ready")
		# Death must publish even though subsequent combat ticks skip this actor.
		p.state.inv = 0
		assert(p.hurt(999))
		assert(machine.body_state == &"dead" and machine.weapon_state == &"disabled")
		assert(not p.get_node("Weapon").visible)
		p.reset(Vector2(350,450))
		assert(machine.body_state == &"idle" and machine.weapon_state == &"disabled")
		assert(anim.elapsed == 0 and anim.recoil == 0 and anim.reload_event.is_empty())
	# Engine frames and game pause/results must not advance manual trees.
	p.advance_visual(.1,true)
	before = machine.body_playback.get_current_play_position()
	game.paused = true
	game._physics_process(.1)
	await process_frame
	assert(is_equal_approx(machine.body_playback.get_current_play_position(),before))
	game.paused = false
	game.result = "DRAW"
	game._physics_process(.1)
	assert(is_equal_approx(machine.body_playback.get_current_play_position(),before))
	p.move_to_room(Vector2(400,450))
	assert(machine.body_state == &"idle")
	game.free()
	await process_frame
	print("PASS: native graphs, independent actors/layers, manual clock, 8-character reload/dodge/fire/death/reset, detached snapshots and unchanged combat")
	quit()
