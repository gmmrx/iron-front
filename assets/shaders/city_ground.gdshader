shader_type spatial;
// World-sized settlement surfaces; no billboard or camera-sized road.
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
uniform sampler2D ground_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 tint : source_color = vec4(0.8, 0.8, 0.75, 1.0);
uniform bool road = false;
uniform bool srgb_out = false;
void fragment() {
	vec3 color = texture(ground_tex, UV).rgb * tint.rgb;
	float opacity = COLOR.a * tint.a;
	if (road) {
		opacity *= 1.0 - smoothstep(0.65, 1.0, abs(UV2.x));
		opacity *= 1.0 - smoothstep(0.55, 1.0, UV2.y);
	}
	ALBEDO = color;
	if (srgb_out) { ALBEDO = pow(max(ALBEDO, vec3(0.0)), vec3(1.0 / 2.2)); }
	ALPHA = opacity;
}
