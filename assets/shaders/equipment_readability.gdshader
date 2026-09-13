shader_type canvas_item;
render_mode unshaded;
uniform vec4 shot_color : source_color = vec4(1.0);
uniform float recolor = 0.0;
uniform float outline = 0.0;
uniform vec2 outline_step = vec2(0.01);
uniform float rainbow = 0.0;
uniform vec4 rainbow_palette[7] : source_color;
varying vec4 vertex_tint;
void vertex() { vertex_tint = COLOR; }
void fragment() {
	vec4 source = texture(TEXTURE, UV);
	float luma = dot(source.rgb, vec3(0.299, 0.587, 0.114));
	vec3 rgb = mix(source.rgb, shot_color.rgb * (0.38 + luma * 0.75), recolor);
	float gradient_position = clamp(1.0 - UV.y, 0.0, 1.0) * 6.0;
	int band = min(int(gradient_position),5);
	vec3 spectrum = mix(rainbow_palette[band].rgb,rainbow_palette[band+1].rgb,smoothstep(0.0,1.0,gradient_position-float(band)));
	rgb = mix(rgb, spectrum * (0.4 + luma * 0.7), rainbow * 0.75 * smoothstep(0.35,0.55,UV.x) * smoothstep(0.4,0.8,luma));
	float edge = min(min(texture(TEXTURE,UV+vec2(outline_step.x,0)).a,texture(TEXTURE,UV-vec2(outline_step.x,0)).a),min(texture(TEXTURE,UV+vec2(0,outline_step.y)).a,texture(TEXTURE,UV-vec2(0,outline_step.y)).a));
	rgb = mix(rgb, vec3(0.055,0.07,0.09), outline * (1.0-edge) * 0.72);
	COLOR = vec4(rgb,source.a) * vertex_tint;
}
