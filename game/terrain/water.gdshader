shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_back, specular_schlick_ggx, world_vertex_coords;

// 拟真水面：多层正弦波解析法线 + 菲涅尔深浅渐变 + 高光
uniform vec4 shallow_color : source_color = vec4(0.10, 0.42, 0.46, 0.62);
uniform vec4 deep_color : source_color = vec4(0.02, 0.14, 0.24, 0.94);
uniform float wave_scale = 0.35;
uniform float wave_speed = 1.1;
uniform float normal_strength = 6.0;

varying vec3 wpos;

void vertex() {
	wpos = VERTEX; // world_vertex_coords 下 VERTEX 已是世界坐标
}

void fragment() {
	vec2 p = wpos.xz * wave_scale;
	float t = TIME * wave_speed;
	// 三层大波 + 两层细波纹，解析求导
	float dx = 0.0;
	float dz = 0.0;
	dx += cos(p.x * 1.7 + t * 1.4) * 0.045 * 1.7;
	dz += cos(p.y * 2.1 - t * 1.2) * 0.040 * 2.1;
	float diag = p.x + p.y;
	dx += cos(diag * 0.9 + t * 0.7) * 0.055 * 0.9;
	dz += cos(diag * 0.9 + t * 0.7) * 0.055 * 0.9;
	dx += cos(p.x * 7.3 - t * 3.1) * 0.010 * 7.3;
	dz += cos(p.y * 6.1 + t * 2.7) * 0.010 * 6.1;
	vec3 n = normalize(vec3(-dx * normal_strength * wave_scale, 1.0, -dz * normal_strength * wave_scale));
	NORMAL = (VIEW_MATRIX * vec4(n, 0.0)).xyz;

	vec3 view_dir = normalize(CAMERA_POSITION_WORLD - wpos);
	float fres = pow(1.0 - clamp(dot(view_dir, n), 0.0, 1.0), 4.0);
	ALBEDO = mix(shallow_color.rgb, deep_color.rgb, fres);
	ALPHA = mix(shallow_color.a, deep_color.a, fres);
	ROUGHNESS = 0.05;
	SPECULAR = 0.7;
	METALLIC = 0.0;
}
