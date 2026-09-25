// Harita ağaçları: vertex renkli, rüzgârda sallanır; zemin yüksekliği GPU'da (instance orijininden) eklenir.
shader_type spatial;
render_mode cull_back, diffuse_lambert;

uniform sampler2D height_tex : filter_linear, repeat_disable;
uniform vec2 map_size = vec2(5120.0, 4348.0);
uniform float height_scale = 0.012;
uniform float brightness = 1.25;

void vertex() {
	vec3 o = MODEL_MATRIX[3].xyz;
	float s = max(length(MODEL_MATRIX[1].xyz), 1e-4);
	float ground = textureLod(height_tex, o.xz / map_size, 0.0).r * height_scale;
	float sway = sin(TIME * 1.3 + o.x * 0.21 + o.z * 0.17) * 0.05 + sin(TIME * 2.3 + o.x * 0.53) * 0.02;
	float k = VERTEX.y * VERTEX.y;
	VERTEX.x += sway * k;
	VERTEX.z += sway * 0.6 * k;
	VERTEX.y += (max(ground, 0.0) + 0.1) / s;
}

void fragment() {
	ALBEDO = COLOR.rgb * brightness;
	ROUGHNESS = 0.9;
	SPECULAR = 0.1;
}
