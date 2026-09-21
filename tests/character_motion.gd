extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var p = load("res://scenes/combat/player.tscn").instantiate()
	root.add_child(p)
	var anim = p.get_node("Animation")
	var machine = anim.get_node("StateMachine")
	var parts = machine.parts
	for id in range(8):
		p.set_character(id)
		p.reset(Vector2(240,220))
		p.add_gun(0)
		p.update_weapon_art()
		p.scale = Vector2.ONE*1.7
		p.sync_visual()
		assert(parts.visible and parts.body.texture != null)
		assert(parts.global_position.is_equal_approx(p.position))
		assert(parts.global_scale.is_equal_approx(p.scale))
		var combat_before: Dictionary = p.state.duplicate(true)
		var inventory_before: Array = p.inventory.duplicate(true)
		var idle_start: Vector2 = parts.get_node("Lean/Body").scale
		p.advance_visual(1.3,false)
		p.sync_visual()
		assert(parts.get_node("Lean/Body").scale.y-idle_start.y > .045)
		# Numeric clips loop cleanly, and idle does not skate either support foot.
		p.advance_visual(1.3,false)
		p.sync_visual()
		assert(parts.get_node("Lean/Body").scale.is_equal_approx(idle_start))
		assert(parts.get_node("Foot0").position == Vector2.ZERO)
		assert(parts.get_node("Foot1").position == Vector2.ZERO)
		assert(p.state == combat_before and p.inventory == inventory_before)
		for direction in [Vector2.RIGHT,Vector2.LEFT,Vector2.UP,Vector2.DOWN]:
			p.state.dir = direction
			p.state.angle = direction.angle()
			var lifted := false
			for frame in range(40):
				p.advance_visual(1.0/60,true)
				p.sync_visual()
				assert(anim.animation_name == "move" and parts.visible)
				var a: float = parts.get_node("Foot0").position.y+parts.foot0.position.y+13
				var b: float = parts.get_node("Foot1").position.y+parts.foot1.position.y+13
				assert(a <= .001 and b <= .001)
				assert(absf(maxf(a,b)) < .001)
				lifted = lifted or minf(a,b) < -3.0
				assert(absf(parts.lean) < .13)
				assert(parts.grip_offset().length() <= 2.001)
				assert(absf(angle_difference(p.get_node("Weapon").rotation,p.state.angle)) < .00001)
			assert(lifted)
		# A stop blends instead of replacing a lifted foot with the idle pose.
		p.state.dir = Vector2.RIGHT
		p.advance_visual(.07,true)
		p.sync_visual()
		var foot_before: Vector2 = parts.get_node("Foot0").position
		var body_before: Vector2 = parts.get_node("Lean/Body").scale
		p.advance_visual(0,false)
		assert(anim.animation_name == "idle")
		assert(parts.get_node("Foot0").position.distance_to(foot_before) < .02)
		assert(parts.get_node("Lean/Body").scale.distance_to(body_before) < .002)
		p.advance_visual(.4,false)
		p.sync_visual()
		assert(parts.get_node("Foot0").position.is_zero_approx())
		assert(parts.get_node("Foot1").position.is_zero_approx())
		assert(absf(parts.lean) < .001)
		# No-input redraws/pause cannot keep moving a spring or a clip.
		var lean_before: float = parts.lean
		var transform_before: Transform2D = parts.body.global_transform
		for repeat in range(4): p.sync_visual()
		await process_frame
		assert(parts.lean == lean_before and parts.body.global_transform == transform_before)
		# Very short move/stop taps, dodge and death interrupt an active blend.
		for repeat in range(3):
			p.advance_visual(.01,true)
			p.advance_visual(.01,false)
			assert(anim.animation_name == "idle")
		p.advance_visual(.01,true)
		p.state.roll = p.dodge_duration
		p.sync_visual()
		assert(anim.animation_name == "roll" and not parts.visible)
		p.state.roll = 0
		p.advance_visual(.01,true)
		assert(parts.visible and anim.animation_name == "move")
		p.state.hp = 0
		p.sync_visual()
		assert(anim.animation_name == "dead" and parts.lean == 0)
		assert(parts.get_node("Lean/Body").scale == Vector2.ONE)
		p.state = combat_before
		assert(p.inventory == inventory_before)
		# Animation calls never moved the actor or altered gameplay timers/resources.
		assert(p.position == combat_before.pos and p.radius == 14)
		p.reset(Vector2(400,250))
		assert(parts.global_position.is_equal_approx(p.position))
		assert(parts.lean == 0 and anim.recoil == 0)
	# Lean uses the same real-time response at 30fps and 120fps.
	var responses: Array[float] = []
	for fps in [30,120]:
		p.reset(Vector2(400,250))
		p.state.dir = Vector2.RIGHT
		for frame in range(fps/5): p.advance_visual(1.0/fps,true)
		responses.append(parts.lean)
	assert(absf(responses[0]-responses[1]) < .00001)
	p.free()
	print("PASS: 8-character keyframes, canvas inheritance, breathing loop, 4-direction support, stop blend, interruption, weapon aim, manual clock and stable lean")
	quit()
