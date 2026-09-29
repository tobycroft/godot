shader_type canvas_item;

uniform float blur_size : hint_range(0.0, 8.0) = 2.0;
uniform sampler2D screen_texture : hint_screen_texture;

void fragment() {
	vec2 px = SCREEN_PIXEL_SIZE * blur_size;
	vec4 sum = vec4(0.0);
	float w = 0.0;
	for (int x = -4; x <= 4; x++) {
		for (int y = -4; y <= 4; y++) {
			sum += texture(screen_texture, SCREEN_UV + vec2(float(x), float(y)) * px);
			w += 1.0;
		}
	}
	COLOR = sum / w;
}
