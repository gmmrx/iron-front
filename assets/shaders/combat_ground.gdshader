shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
uniform sampler2D smoke_atlas : filter_linear_mipmap, repeat_disable;
uniform bool srgb_out = false;
varying vec4 effect;
void vertex() { effect = INSTANCE_CUSTOM; }
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float grain = texture(smoke_atlas, (UV * 0.96 + 0.02) * 0.5).a;
	float a;
	if (effect.z < 0.5) {
		// Broken low dust skirt, not a bright circular shock-wave.
		float ring = exp(-pow((r - 0.63) / 0.19, 2.0));
		a = ring * grain * 0.65;
	} else {
		a = (1.0 - smoothstep(0.1, 0.8, r)) * grain;
	}
	ALBEDO = srgb_out ? COLOR.rgb : pow(max(COLOR.rgb, vec3(0.0)), vec3(2.2));
	ALPHA = a * COLOR.a;
}
