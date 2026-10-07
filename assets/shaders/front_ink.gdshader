// Static, perpendicular ImageGen stencil; curvature-limited world-space ribbon.
// UV.x: sınır boyunca uzunluk (dünya birimi), UV.y: 0 bizim yanın dış kenarı, 1 düşman yanının dış kenarı (sınır 0,5'te).
// UV2: düşmana doğru yön (xz).
// CUSTOM0.xy: bu noktadaki bölge çifti (bizim, düşmanın): fare vurgusu ve muharebe.
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;

uniform float band = 8.0;       // fixed world width, not camera distance
uniform vec3 friendly_ink = vec3(0.64, 0.86, 0.81);
uniform sampler2D comb_tex : filter_linear_mipmap_anisotropic, repeat_enable;
uniform float period = 4.0;     // fixed world spacing
uniform float opacity = 0.70;
uniform int hover_a = 0;        // fare bu kesitin üstünde (bölge çifti): koyu ve kalın
uniform int hover_b = 0;
uniform bool srgb_out = false;  // Compatibility (web) renderer: çıkış sRGB
uniform sampler2D province_tex : filter_nearest, repeat_disable;
uniform sampler2D data_tex : filter_nearest, repeat_disable;
uniform bool province_mask_enabled = false;
uniform bool wrap_x = false;
uniform vec2 map_size = vec2(16384.0, 8106.0);

#include "res://assets/shaders/occupation_ink.gdshaderinc"

varying float emph;
varying vec2 world_position;
varying flat vec2 side_controls;

int held_by(int id) {
	vec4 data = texelFetch(data_tex, ivec2(id % 256, id / 256), 0);
	int held = int(round(data.g * 255.0));
	return held > 0 ? held : int(round(data.r * 255.0));
}

void vertex() {
	int a = int(round(CUSTOM0.x));
	int b = int(round(CUSTOM0.y));
	emph = (hover_a > 0 && a == hover_a && b == hover_b) ? 1.0 : 0.0;
	side_controls = vec2(0.0);
	if (province_mask_enabled) { side_controls = vec2(float(held_by(a)), float(held_by(b))); }
	// Neither zoom, hover nor combat changes the geometry.
	float side = UV.y - 0.5;
	VERTEX.xz += UV2 * side * band;
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
	float y = UV.y;
	// The original PNG is preserved. Crop its transparent margins in UV space.
	// Derivatives precede wrapping, avoiding a mip discontinuity at each repeat.
	vec2 stencil_uv = vec2(UV.x / (period * 23.0), mix(303.0, 418.0, (y - 0.5) * 2.0) / 724.0);
	vec2 dx = dFdx(stencil_uv);
	vec2 dy = dFdy(stencil_uv);
	float marks = textureGrad(comb_tex, vec2(fract(stencil_uv.x), stencil_uv.y), dx, dy).a;
	marks *= step(0.5, y); // Teeth only toward the opposing side; no interleaved double comb.
	marks *= smoothstep(0.0, 0.06, y) * (1.0 - smoothstep(0.94, 1.0, y));
	// A fine seam survives subpixel hatch filtering without becoming a thick distant ribbon.
	float seam_width = max(1.5, fwidth(y) * band * 2.0);
	float seam = clamp(0.5 - (abs(y - 0.5) * band - seam_width * 0.5)
		/ max(fwidth(y) * band, 0.0001), 0.0, 1.0);
	float a = max(marks, seam) * opacity * mix(1.0, 1.08, emph);
	if (a < 0.003) { discard; }
	if (province_mask_enabled) {
		vec2 point = world_position;
		if (wrap_x) { point.x = mod(point.x, map_size.x); }
		if (point.x < 0.0 || point.y < 0.0 || point.x >= map_size.x || point.y >= map_size.y) { discard; }
		vec4 pixel = texelFetch(province_tex, ivec2(point), 0);
		int pid = int(round(pixel.r * 255.0)) + int(round(pixel.a * 255.0)) * 256;
		int held = held_by(pid);
		// Keep the smoothed spine continuous across the raster border staircase.
		if (held <= 0 || (float(held) != side_controls.x && float(held) != side_controls.y)) { discard; }
	}
	vec3 c = friendly_ink * mix(1.0, 0.92, emph);
	ALBEDO = srgb_out ? c : pow(c, vec3(2.2));
	ALPHA = clamp(a, 0.0, 1.0);
}
