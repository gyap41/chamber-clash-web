shader_type canvas_item;
render_mode unshaded;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float effect_age = 0.0;
uniform float strength = 0.0;
void fragment() {
	vec2 p = (UV - vec2(0.5)) * 2.0;
	float r = length(p);
	float angle = atan(p.y, p.x);
	float mask = 1.0 - smoothstep(0.65, 0.98, r);
	// At most three screen pixels; never distort HUD or the entire viewport.
	vec2 tangent = vec2(-p.y, p.x);
	vec2 shift = (p * 1.8 + tangent * sin(r * 13.0 - effect_age * 3.0)) * mask * strength * SCREEN_PIXEL_SIZE;
	vec3 background = texture(screen_texture, SCREEN_UV + shift).rgb;
	float spiral = pow(0.5 + 0.5 * sin(angle * 3.0 + r * 16.0 - effect_age * 4.5), 7.0);
	float belt = exp(-pow((r - 0.36) * 8.0, 2.0));
	float halo = exp(-pow((r - 0.23) * 20.0, 2.0));
	float inner = 1.0 - smoothstep(0.13, 0.20, r);
	vec3 light = vec3(0.33, 0.09, 0.65) * spiral * belt * 0.6;
	light += vec3(0.52, 0.31, 0.75) * halo * (0.7 + sin(effect_age * 5.0) * 0.1);
	vec3 result = background * (1.0 - inner * 0.8 * strength) + light * strength;
	COLOR = vec4(result, mask * strength);
}
