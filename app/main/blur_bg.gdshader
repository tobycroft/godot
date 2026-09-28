shader_type canvas_item;

uniform float blur : hint_range(0.0, 1.0) = 0.2;

void fragment() {
	vec2 texel = vec2(1.0) / vec2(textureSize(TEXTURE, 0));
	vec2 radius = blur * 16.0 * texel;
	vec4 color = vec4(0.0);
	float count = 0.0;
	for (int x = -4; x <= 4; x++) {
		for (int y = -4; y <= 4; y++) {
			vec2 offset = vec2(float(x), float(y)) * radius;
			color += texture(TEXTURE, UV + offset);
			count += 1.0;
		}
	}
	COLOR = color / count;
}
