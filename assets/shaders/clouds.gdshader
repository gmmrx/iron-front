// Uzak zoom'da beliren bulut katmanı (harita üstünde yatay düzlem)
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;

#include "res://assets/shaders/clouds.gdshaderinc"

uniform float cloud_amount = 0.0;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float d = cloud_density(world_pos.xz, TIME);
	float edge = cloud_density(world_pos.xz + vec2(25.0, 15.0), TIME);
	vec3 col = mix(vec3(0.78, 0.8, 0.84), vec3(1.0), smoothstep(0.2, 1.0, d - edge * 0.5 + 0.5));
	ALBEDO = col;
	ALPHA = d * 0.62 * cloud_amount;
}
