shader_type canvas_item;
render_mode unshaded;
// Trial (docs/art/VISUAL_STYLE_GUIDE.md 3.2/3.5): for a CanvasGroup wrapping one enemy.
// Lifts the opaque body and adds an outline in a darkened copy of the adjacent body colour.
// Low-alpha pixels (cast shadow, glows) keep their colour. Not connected to the game yet.
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform float gamma = 1.0;
uniform float contrast = 1.0;
uniform float brightness = 0.0;
uniform float saturation = 1.0;
uniform float body_alpha = 0.6;
uniform float outline_px = 2.0;
uniform float outline_darken = 0.35;

vec3 straight(vec4 c) { return c.a > 0.0001 ? c.rgb / c.a : vec3(0.0); }

void fragment() {
	vec4 c = textureLod(screen_texture, SCREEN_UV, 0.0);
	vec3 rgb = straight(c);
	float body = smoothstep(body_alpha - 0.1, body_alpha + 0.1, c.a);
	vec3 toned = pow(max(rgb, vec3(0.0)), vec3(gamma));
	toned = (toned - 0.5) * contrast + 0.5 + brightness;
	float luma = dot(toned, vec3(0.2126, 0.7152, 0.0722));
	toned = clamp(mix(vec3(luma), toned, saturation), 0.0, 1.0);
	rgb = mix(rgb, toned, body);
	float near = 0.0;
	vec3 edge_rgb = vec3(0.0);
	float count = 0.0;
	for (int i = 0; i < 8; i++) {
		float a = float(i) * 0.785398;
		for (int r = 1; r <= 2; r++) {
			vec2 offset = vec2(cos(a), sin(a)) * outline_px * float(r) * 0.5 * SCREEN_PIXEL_SIZE;
			vec4 s = textureLod(screen_texture, SCREEN_UV + offset, 0.0);
			float w = step(body_alpha, s.a);
			near = max(near, w);
			edge_rgb += straight(s) * w;
			count += w;
		}
	}
	float line = near * (1.0 - body);
	vec3 line_rgb = edge_rgb / max(count, 1.0) * outline_darken;
	COLOR = vec4(mix(rgb, line_rgb, line), mix(c.a, 1.0, line));
}
