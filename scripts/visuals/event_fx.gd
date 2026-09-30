extends Node2D
# Short code-drawn effects for exploration events (docs/art/production/event-rooms). Time only advances through
# step(), which the game calls while unpaused, so menus freeze effects mid-flight. Two instances are used:
# one under actors for floor rings, one above them for pillars, sparks and text. clear() on every room change.
var effects: Array = []
var particles: Array = []
var banner: Label
var flash: ColorRect
var banner_time := 0.0
var banner_life := 0.0
var flash_time := 0.0
var flash_life := 0.0

# Screen-space banner and flash, created only on the upper instance.
func enable_screen() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 18
	add_child(layer)
	flash = ColorRect.new()
	flash.size = Vector2(1120,800)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.color = Color(0,0,0,0)
	layer.add_child(flash)
	banner = Label.new()
	banner.position = Vector2(0,250)
	banner.size = Vector2(1120,60)
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.add_theme_font_size_override("font_size",40)
	banner.add_theme_color_override("font_shadow_color",Color.BLACK)
	banner.add_theme_constant_override("shadow_offset_x",3)
	banner.add_theme_constant_override("shadow_offset_y",3)
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.modulate.a = 0
	layer.add_child(banner)

func clear() -> void:
	effects.clear()
	particles.clear()
	banner_life = 0.0
	flash_life = 0.0
	if banner != null: banner.modulate.a = 0
	if flash != null: flash.color.a = 0
	queue_redraw()

func step(dt: float) -> void:
	for effect in effects: effect.t += dt
	effects = effects.filter(func(effect): return effect.t < effect.life)
	for particle in particles:
		particle.t += dt
		particle.vel += particle.gravity*dt
		particle.pos += particle.vel*dt
		if particle.has("target"):
			# Homing particles bend toward their target and arrive by the end of their life.
			var remaining: float = maxf(particle.life-particle.t,.05)
			particle.vel = particle.vel.lerp((particle.target-particle.pos)/remaining,clampf(dt*6.0,0,1))
	particles = particles.filter(func(particle): return particle.t < particle.life)
	if banner != null and banner_life > 0:
		banner_time += dt
		var fade := clampf(minf(banner_time/.15,(banner_life-banner_time)/.4),0,1)
		banner.modulate.a = fade
		if banner_time >= banner_life: banner_life = 0.0
	if flash != null and flash_life > 0:
		flash_time += dt
		flash.color.a = .45*clampf(1.0-flash_time/flash_life,0,1)
		if flash_time >= flash_life: flash_life = 0.0
	queue_redraw()

func active() -> bool:
	return not effects.is_empty() or not particles.is_empty() or banner_life > 0 or flash_life > 0

# Deterministic spread so identical inputs give identical effects (captures, tests).
func burst(at: Vector2, color: Color, count: int = 10, speed: float = 120.0, life: float = .55, gravity: float = 260.0, size: float = 3.0) -> void:
	for index in range(count):
		var angle := TAU*index/count+.37*index
		var velocity := Vector2.from_angle(angle)*speed*(.6+.4*fmod(index*.618,1.0))+Vector2(0,-speed*.5)
		particles.append({"pos":at,"vel":velocity,"gravity":Vector2(0,gravity),"t":0.0,"life":life*(.75+.25*fmod(index*.414,1.0)),"color":color,"size":size})

# Particles that travel from `from` to `to` (an offering drawn into the altar).
func stream(from: Vector2, to: Vector2, color: Color, count: int = 14, life: float = .75) -> void:
	for index in range(count):
		var side := Vector2.from_angle(TAU*index/count)*40
		particles.append({"pos":from+side*.3,"vel":side*3.0,"gravity":Vector2.ZERO,"t":-index*.025,"life":life,"color":color,"size":3.5,"target":to})

func ring(at: Vector2, color: Color, from_radius: float, to_radius: float, life: float = .5, width: float = 4.0) -> void:
	effects.append({"kind":"ring","pos":at,"color":color,"a":from_radius,"b":to_radius,"t":0.0,"life":life,"width":width})

func pillar(at: Vector2, color: Color, height: float = 220.0, life: float = .6, width: float = 46.0) -> void:
	effects.append({"kind":"pillar","pos":at,"color":color,"height":height,"t":0.0,"life":life,"width":width})

func float_text(at: Vector2, text: String, color: Color, life: float = .7) -> void:
	effects.append({"kind":"text","pos":at,"text":text,"color":color,"t":0.0,"life":life})

# Shrinking warning circle where an enemy is about to act.
func warning(at: Vector2, radius: float, life: float) -> void:
	effects.append({"kind":"warning","pos":at,"radius":radius,"t":0.0,"life":life})

func show_banner(text: String, color: Color, life: float = 1.4) -> void:
	if banner == null: return
	banner.text = text
	banner.add_theme_color_override("font_color",color)
	banner_time = 0.0
	banner_life = life

func screen_flash(color: Color, life: float = .3) -> void:
	if flash == null: return
	flash.color = Color(color,.45)
	flash_time = 0.0
	flash_life = life

func _draw() -> void:
	var font := ThemeDB.fallback_font
	for effect in effects:
		var k: float = effect.t/effect.life
		match effect.kind:
			"ring":
				draw_set_transform(effect.pos,0,Vector2(1,.5))
				draw_arc(Vector2.ZERO,lerpf(effect.a,effect.b,1.0-pow(1.0-k,2)),0,TAU,40,Color(effect.color,effect.color.a*(1.0-k)),effect.width)
				draw_set_transform(Vector2.ZERO)
			"pillar":
				var grow := minf(k/.2,1.0)
				var alpha: float = (1.0-k)*.8
				var width: float = effect.width*(1.0-k*.6)
				var top: float = effect.height*grow
				draw_rect(Rect2(effect.pos+Vector2(-width*.5,-top),Vector2(width,top)),Color(effect.color,alpha*.35))
				draw_rect(Rect2(effect.pos+Vector2(-width*.18,-top),Vector2(width*.36,top)),Color(Color.WHITE.lerp(effect.color,.4),alpha*.7))
			"text":
				var rise := Vector2(0,-36*k)
				var width := font.get_string_size(effect.text,HORIZONTAL_ALIGNMENT_LEFT,-1,16).x
				draw_string(font,effect.pos+rise+Vector2(-width*.5+1,1),effect.text,HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color(0,0,0,1.0-k))
				draw_string(font,effect.pos+rise+Vector2(-width*.5,0),effect.text,HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color(effect.color,1.0-k))
			"warning":
				var pulse := .5+.5*sin(effect.t*18.0)
				draw_set_transform(effect.pos,0,Vector2(1,.5))
				draw_circle(Vector2.ZERO,effect.radius*(1.0-k*.5),Color(1,.2,.15,.18+.12*pulse))
				draw_arc(Vector2.ZERO,effect.radius*(1.3-k*.8),0,TAU,32,Color(1,.3,.2,.8),3)
				draw_set_transform(Vector2.ZERO)
	for particle in particles:
		if particle.t < 0: continue
		var fade: float = 1.0-particle.t/particle.life
		draw_circle(particle.pos,particle.size*(.5+.5*fade),Color(particle.color,particle.color.a*fade))
