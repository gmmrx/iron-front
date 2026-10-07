// Solid cartographic ink; outline geometry includes every edge of the arrowhead.
shader_type spatial;
// Orders are a cartographic overlay: terrain depth must never cut holes in the ink.
render_mode unshaded, blend_mix, cull_disabled, depth_test_disabled, shadows_disabled;
uniform bool srgb_out = false;
uniform float opacity = 0.60;
uniform float zoom_opacity = 1.0;

void fragment() {
	vec3 ink = pow(COLOR.rgb, vec3(2.2));
	ALBEDO = srgb_out ? pow(max(ink, vec3(0.0)), vec3(1.0 / 2.2)) : ink;
	ALPHA = opacity * zoom_opacity * mix(0.22, 1.0, smoothstep(0.0, 0.22, UV.x));
}
