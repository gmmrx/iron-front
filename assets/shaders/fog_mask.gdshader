// Savaş sisi maskesi (CloudFog, 1 geçiş): harita CELL pikselik hücrelere bölünür; hücreye biraz taşan 4×4 noktada
// keşfedilmemiş payı (R: 0 hepsi keşfedilmiş, 1 hiçbiri). Doğrusal süzülen sonuç bulut hacminde bölge sınırlarında dik
// bulut duvarı yerine yumuşak geçiş verir. Yalnız keşif değişince bir kez çizilir.
shader_type canvas_item;
render_mode blend_disabled, unshaded;

uniform sampler2D province_tex : filter_nearest, repeat_disable;
uniform sampler2D fog_tex : filter_nearest, repeat_disable;   // bölge başına R: 1 keşfedilmiş, 0 bulut
uniform vec2 map_size = vec2(5120.0, 4348.0);
uniform vec2 grid = vec2(320.0, 272.0);
uniform float cell = 16.0;
uniform bool wrap_x = false;

int province_at(vec2 p) {
	if (wrap_x) { p.x = mod(p.x, map_size.x); }
	ivec2 q = ivec2(clamp(p, vec2(0.0), map_size - 1.0));
	vec4 c = texelFetch(province_tex, q, 0);
	return int(round(c.r * 255.0)) + int(round(c.a * 255.0)) * 256;
}

void fragment() {
	vec2 base = (floor(UV * grid) + 0.5) * cell;
	float sum = 0.0;
	for (int y = 0; y < 4; y++) {
		for (int x = 0; x < 4; x++) {
			vec2 p = base + (vec2(float(x), float(y)) / 3.0 - 0.5) * cell * 1.5;
			int id = province_at(p);
			if (id > 0) {
				sum += 1.0 - texelFetch(fog_tex, ivec2(id % 256, id / 256), 0).r;
			}
		}
	}
	COLOR = vec4(sum / 16.0, 0.0, 0.0, 1.0);
}
