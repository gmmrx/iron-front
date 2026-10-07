shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
uniform bool srgb_out = false;
varying vec4 effect;
void vertex() { effect = INSTANCE_CUSTOM; }
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float age = effect.x;
	float a;
	if (effect.z < 0.5) {
		// Directional gas jet: narrow at the muzzle, ragged farther along the bore.
		float along = 1.0 - UV.y;
		float flutter = 0.87 + 0.13 * sin(along * 37.0 + p.x * 12.0 + effect.y);
		float width = (0.17 + 0.33 * sin(along * 3.14159)) * flutter;
		a = exp(-p.x * p.x / max(width * width, 0.01) * 3.0) * pow(1.0 - along, 0.65);
		a *= smoothstep(0.0, 0.09, UV.y);
	} else {
		// Short streak with a hot head and soft tapered tail, never a solid box.
		float along = 1.0 - UV.y; // Quad +Y is flight direction, UV.y=0 is the head.
		a = exp(-p.x * p.x * 22.0) * smoothstep(0.0, 0.16, along) * (0.2 + 0.8 * along);
		a *= 1.0 - smoothstep(0.88, 1.0, along);
	}
	a *= COLOR.a * (1.0 - smoothstep(0.55, 1.0, age));
	vec3 rgb = mix(COLOR.rgb, vec3(1.6, 1.35, 0.88), exp(-p.x * p.x * 90.0) * 0.65);
	ALBEDO = srgb_out ? rgb : pow(max(rgb, vec3(0.0)), vec3(2.2));
	ALPHA = a;
}
