// Ülke sınırına yakınlık (CountryRim, 2. geçiş): radius hücrelik diskte en yakın sınır hücresi; sonuç 1 sınırda, radius
// hücre uzakta 0 (doğrusal). Doku doğrusal süzülerek örneklenir (map3d.gdshader rim_tex): hücreler görünmez.
shader_type canvas_item;
render_mode blend_disabled, unshaded;

uniform sampler2D edge_tex : filter_nearest, repeat_disable;
uniform vec2 grid = vec2(320.0, 272.0);
uniform int radius = 6;
uniform bool wrap_x = false;

void fragment() {
	ivec2 cid = ivec2(floor(UV * grid));
	ivec2 g = ivec2(grid);
	float best = float(radius) + 1.0;
	for (int y = -radius; y <= radius; y++) {
		for (int x = -radius; x <= radius; x++) {
			float d = length(vec2(float(x), float(y)));
			if (d >= best) { continue; }
			ivec2 q = cid + ivec2(x, y);
			if (q.y < 0 || q.y >= g.y) { continue; }
			if (wrap_x) { q.x = ((q.x % g.x) + g.x) % g.x; }
			else if (q.x < 0 || q.x >= g.x) { continue; }
			if (texelFetch(edge_tex, q, 0).r > 0.5) { best = d; }
		}
	}
	float rim = 1.0 - clamp(best / float(radius), 0.0, 1.0);
	COLOR = vec4(rim, rim, rim, 1.0);
}
