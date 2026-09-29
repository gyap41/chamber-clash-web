shader_type canvas_item;
uniform vec4 water_bounds;
uniform float motion_time = 0.0;
void fragment() {
	vec2 q = (UV-water_bounds.xy)/water_bounds.zw;
	float edge = min(min(q.x,1.0-q.x),min(q.y,1.0-q.y));
	float mask = smoothstep(0.0,0.07,edge);
	vec2 wave = vec2(sin(q.y*15.0+motion_time*1.4),cos(q.x*12.0-motion_time*1.1));
	wave += .45*vec2(cos(q.x*21.0-motion_time*.9),sin(q.y*19.0+motion_time*1.3));
	vec2 sample_uv = UV+wave*water_bounds.zw*vec2(.01,.018)*mask;
	vec4 source = texture(TEXTURE,sample_uv);
	float sheen = sin(q.x*10.0+q.y*8.0+motion_time*.9)*.04;
	sheen += pow(.5+.5*sin(q.x*23.0-q.y*17.0-motion_time*1.1),8.0)*.045;
	float rings = 0.0;
	for (int i=0;i<3;i++) {
		float n = float(i);
		float age = mod(motion_time+n*2.73,7.7);
		vec2 center = vec2(.26+n*.23,.45+sin(n*4.0)*.16);
		float distance_to_drop = length((q-center)*vec2(1.0,.48));
		float ring = 1.0-smoothstep(.002,.009,abs(distance_to_drop-age*.065));
		rings += ring*(1.0-smoothstep(.1,2.2,age))*.14;
		// A short falling glint reaches the same point immediately before its ring starts.
		float fall = clamp((age-7.35)/.35,0.0,1.0);
		vec2 drop = center-vec2(0.0,(1.0-fall)*.18);
		float glint = (1.0-smoothstep(.003,.012,abs(q.x-drop.x))) * (1.0-smoothstep(.009,.025,abs(q.y-drop.y)));
		rings += glint*smoothstep(7.35,7.42,age)*.22;
	}
	COLOR = vec4(source.rgb+vec3(.55,.8,.85)*(sheen+rings)*mask,source.a*mask);
}
