shader_type canvas_item;
render_mode unshaded;
uniform float motion_time = 0.0;
uniform float phase = 0.0;
uniform float strength = 1.0;
float flame_mask(vec4 c) {
	return smoothstep(.12,.4,c.r-c.b)*smoothstep(.3,.65,c.r)*c.a;
}
void fragment() {
	vec4 base = texture(TEXTURE,UV);
	float mask = flame_mask(base);
	float t = motion_time+phase;
	vec2 offset = vec2(sin(UV.y*44.0-t*5.7),cos(UV.x*32.0+t*4.1))*.009*strength*mask;
	vec4 moving = texture(TEXTURE,UV+offset);
	// Never carry dark iron bars or stone into the luminous portion.
	vec3 fire = mix(base.rgb,moving.rgb,flame_mask(moving));
	float pulse = .94+.07*sin(t*6.3)+.035*sin(t*11.7);
	COLOR = vec4(fire*pulse,mask*.9);
}
